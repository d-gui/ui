//#include <stdlib.h>
import core.stdc.stdlib;
//#include <assert.h>
//#include <stdint.h>
import core.stdc.stdint;
//#include <ctype.h>
//#include "opengl.h"
import deps.gl3;
//#include "gpufont_data.h"
import gpufont_data;
//#include "gpufont_draw.h"
import gpufont_draw;
//#include <stddef.h>
//#include <stdint.h>

/*
Inputs:
	A block of ASCII/unicode/wchar_t/HTML text
	Font metrics
Output:
	Array of glyph index/position tuples
*/


//
struct GlyphBuffer 
{
	size_t      batch_count;   /* how many batches */
	size_t      total_glyphs;
	GlyphCoord* positions;     /* glyph position array */
	GlyphIndex* glyph_indices; /* one glyph index per batch */
	size_t*     batch_len;     /* length of each batch */
	GLuint 		positions_vbo;
}

struct TempChar
{
	GlyphIndex glyph;
	int32_t    line_num;
	int32_t    pos_x;
}

static 
void upload_positions( GlyphBuffer* buf, GLenum hint )
{
	glGenBuffers( 1, &buf.positions_vbo );
	glBindBuffer( GL_ARRAY_BUFFER, buf.positions_vbo );
	glBufferData( GL_ARRAY_BUFFER, buf.total_glyphs * 2 * buf.positions[0].sizeof, buf.positions, hint );
}

static 
size_t init_glyph_positions( Font* font, TempChar* chars, uint32_t* text, size_t text_len, int max_line_len )
{
	int32_t pos_x = 0;
	int32_t line = 0;
	size_t n = 0;
	int column = 0;
	size_t num_out = 0;
	
	for( n=0; n<text_len; n++ )
	{
		GlyphIndex glyph;
		uint32_t cha = text[n];
		int is_newline = 0;
		int is_visible = 1;
		
		glyph = get_cmap_entry( font, cha );
		chars[num_out].glyph = glyph;
		chars[num_out].pos_x = pos_x - font.hmetrics[ glyph ].lsb;
		chars[num_out].line_num = line;
		
		if ( cha == '\n' ) {
			is_newline = 1;
			is_visible = 0;
		} else if ( column == max_line_len ) {
			is_newline = 1;
		}
		
		if ( is_newline ) {
			column = 0;
			pos_x = 0;
			line += 1;
		} else if ( is_visible ) {
			pos_x += font.hmetrics[ glyph ].adv_width;
			column++;
		}
		
		num_out += is_visible;
	}
	
	return num_out;
}

extern (C) static 
int sort_func( const(void*) x, const(void*) y ) 
{
	TempChar* a = cast( TempChar* ) x;
	TempChar* b = cast( TempChar* ) y;
	if ( a.glyph > b.glyph )
		return -1;
	if ( a.glyph < b.glyph )
		return 1;
	return 0;
}

/* fields of 'output':
"positions" MUST have been allocated to at least 2*text_len floats
"glyph_indices" will be allocated if it hasn't been already
"batch_len" will also be allocated if necessary, but "batch_len" must be null if "glyph_indices" is also null
"glyph_indices" and "batch_len" must be in the same contiguous block of memory one after another
*/
static int do_simple_layout_internal( Font* font, uint32_t* text, size_t text_len, int max_line_len, float line_height_scale, GlyphBuffer* output, TempChar* chars )
{
	const long LINEH_PREC = 10;
	long line_height = cast( long )( ( ( font.horz_ascender - font.horz_descender + font.horz_linegap ) << LINEH_PREC ) * line_height_scale );
	size_t n, num_batches, cur_batch, cur_batch_len;
	GlyphIndex prev_glyph;
	
	assert( text_len > 0 );
	assert( output );
	assert( output.positions );
	assert( chars );
	
	/* Map character codes to glyph indices. Then compute x and y coordinates for each glyph */
	text_len = init_glyph_positions( font, chars, text, text_len, max_line_len );
	
	/* Put same glyphs into the same batches */
	qsort( chars, text_len, (*chars).sizeof, &sort_func );
	
	/* See out how many batches there are */
	prev_glyph = chars[0].glyph;
	num_batches = 1;
	for( n=1; n<text_len; n++ )
	{
		if ( chars[n].glyph != prev_glyph ) {
			prev_glyph = chars[n].glyph;
			num_batches++;
		}
	}
	
	if ( !output.glyph_indices )
	{
		output.glyph_indices = cast(typeof(output.glyph_indices)) malloc( num_batches * ( ( output.glyph_indices[0] ).sizeof + ( output.batch_len ).sizeof ) );
		output.batch_len = cast(size_t*)( output.glyph_indices + num_batches );
		
		if ( !output.glyph_indices )
			return 0;
	}
	
	assert( output.batch_len );
	output.batch_count = num_batches;
	output.total_glyphs = text_len;
	
	/* Write batch information */
	prev_glyph = chars[0].glyph;
	cur_batch = cur_batch_len = 0;
	for( n=0; n<text_len; n++ )
	{
		GlyphCoord *p = output.positions + 2 * n;
		p[0] = chars[n].pos_x;
		p[1] = chars[n].line_num * line_height >> LINEH_PREC;
		
		if ( chars[n].glyph != prev_glyph )
		{
			output.batch_len[ cur_batch ] = cur_batch_len;
			output.glyph_indices[ cur_batch ] = prev_glyph;
			cur_batch++;
			
			cur_batch_len = 0;
			prev_glyph = chars[n].glyph;
		}
		
		cur_batch_len++;
	}
	
	/* Initialize the final batch */
	output.batch_len[ cur_batch ] = cur_batch_len;
	output.glyph_indices[ cur_batch ] = prev_glyph;
	
	return 1;
}

enum MAX_LIVE_LEN = 200;
void draw_text_live( Font* font, uint32_t* text, size_t text_len, int max_line_len, float line_height_scale, float* global_transform, int draw_flags )
{
	GlyphBuffer batch;
	GlyphIndex[MAX_LIVE_LEN] glyph_indices;
	size_t[MAX_LIVE_LEN] batch_len;
	GlyphCoord[2*MAX_LIVE_LEN] positions;
	TempChar[MAX_LIVE_LEN] chars;
	
	if ( !text_len )
		return;
	
	if ( text_len > MAX_LIVE_LEN )
		text_len = MAX_LIVE_LEN;
	
	batch.positions     = positions.ptr;
	batch.glyph_indices = glyph_indices.ptr;
	batch.batch_len     = batch_len.ptr;
	batch.batch_count   = 0;
	
	do_simple_layout_internal( font, text, text_len, max_line_len, line_height_scale, &batch, chars.ptr );
	upload_positions( &batch, GL_STREAM_DRAW );
	draw_glyph_buffer( font, &batch, global_transform, draw_flags );
	glDeleteBuffers( 1, &batch.positions_vbo );
}

static GlyphBuffer THE_EMPTY_BUFFER = {
	0, 0, null, null, null, 0
};

GlyphBuffer* do_simple_layout( Font* font, uint32_t* text, size_t text_len, int max_line_len, float line_height_scale )
{
	GlyphBuffer *b = null;
	TempChar *chars = null;
	GlyphCoord *positions = null;
	
	if ( !text_len )
		return &THE_EMPTY_BUFFER;
	
	b = cast(typeof(b)) malloc( (*b).sizeof );
	chars = cast(typeof(chars)) malloc( text_len * (*chars).sizeof );
	positions = cast(typeof(positions)) malloc( text_len * (*positions).sizeof * 2 );
	
	if ( !chars || !b || !positions )
		goto error_handler;
	
	b.positions = positions;
	b.glyph_indices = null;
	b.batch_len = null;
	b.batch_count = 0;
	
	if ( !do_simple_layout_internal( font, text, text_len, max_line_len, line_height_scale, b, chars ) )
		goto error_handler;
	
	upload_positions( b, GL_STATIC_DRAW );
	
	free( chars );
	free( b.positions );
	b.positions = null;
	
	/* Success */
	return b;
	
error_handler:;
	if ( b ) free( b );
	if ( chars ) free( chars );
	if ( positions ) free( positions );
	return null;
}

void draw_glyph_buffer( Font* font, GlyphBuffer* buf, float* global_transform, int draw_flags )
{
	size_t b, num_batches = buf.batch_count;
	size_t first = 0;
	for( b=0; b<num_batches; b++ )
	{
		bind_glyph_positions( buf.positions_vbo, first );
		draw_glyphs( font, global_transform, buf.glyph_indices[b], buf.batch_len[b], draw_flags );
		first += buf.batch_len[b];
	}
}

void delete_glyph_buffer( GlyphBuffer* buf )
{
	if ( buf != &THE_EMPTY_BUFFER )
	{
		if ( buf.positions_vbo ) glDeleteBuffers( 1, &buf.positions_vbo );
		if ( buf.positions ) free( buf.positions );
		if ( buf.glyph_indices ) free( buf.glyph_indices );
		free( buf );
	}
}
