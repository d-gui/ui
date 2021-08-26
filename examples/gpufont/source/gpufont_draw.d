module gpufont_draw;

import core.stdc.stdio  : printf;
import deps.gl3;
import gpufont_data;


/* Draw flags. Nothing will be drawn if flags are zero */
enum {
    F_DRAW_POINTS  = 4,   /* Draw points */
    F_DRAW_CURVE   = 8,   /* Draw curves */
    F_DRAW_SOLID   = 32,  /* Draw solid triangles */
    F_DEBUG_COLORS = 64,  /* Draw different parts of the glyph using certain colors. This flag will overwrite whatever color was specified with set_text_color */
    F_ALL_SOLID    = 128, /* Draw everything using FILL_SOLID (curves appear as solid triangles) */
    F_DRAW_TRIS    = ( F_DRAW_CURVE | F_DRAW_SOLID ) /* The "normal" mode */
}

/* don't need bloated opengl header for just this one type */
alias GLuint_ = uint;

//
auto GET_UINT_TYPE( T )()
{
    return 
        ( T.sizeof == 1 ? 
            GL_UNSIGNED_BYTE : 
            ( T.sizeof == 2 ? 
                GL_UNSIGNED_SHORT : 
                GL_UNSIGNED_INT 
            ) 
        );
}

auto GET_INT_TYPE( T )()
{
    return 
        T.sizeof == 1 ? 
            GL_BYTE :
            ( T.sizeof == 2 ? 
                GL_SHORT : 
                GL_INT
            );
}

auto GET_FLOAT_TYPE( T )()
{
    return 
        T.sizeof == 4 ? 
            GL_FLOAT : 
            GL_DOUBLE;
}

auto GET_INTFLOAT_TYPE( T )()
{
    return 
        ( cast( T ) 0.1 ) ? 
            GET_FLOAT_TYPE!( T ) :
            GET_INT_TYPE!( T ) ;
}

auto GLYPH_INDEX_GL_TYPE()
{
    return GET_UINT_TYPE!( GlyphIndex );  
} 

auto POINT_INDEX_GL_TYPE()
{ 
    return GET_UINT_TYPE!( PointIndex ); 
}

auto POINT_FLAG_GL_TYPE() 
{
    return GET_UINT_TYPE!( PointFlag );
}

auto POINT_COORD_GL_TYPE() 
{
    return GET_INTFLOAT_TYPE!( PointCoord );
}

pragma( inline, true )
auto GLYPH_COORD_GL_TYPE() 
{
    return GET_INTFLOAT_TYPE!( GlyphCoord );
}

/* Uniform locations */
struct Tuniforms
{
    GLint the_matrix;
    GLint the_color;
    GLint fill_mode;
    GLint coord_scale;
}

Tuniforms uniforms;

enum FillMode
{
    FILL_CURVE = 0,
    FILL_SOLID = 2,
    SHOW_FLAGS = 3
}
enum
{
    FILL_CURVE = FillMode.FILL_CURVE,
    FILL_SOLID = FillMode.FILL_SOLID,
    SHOW_FLAGS = FillMode.SHOW_FLAGS
}

/* Vertex shader attribute numbers */
enum 
{
    ATTRIB_POS       = 0,
    ATTRIB_FLAG      = 1,
    ATTRIB_GLYPH_POS = 2
}

/* The shader program used to draw text */
static GLuint the_prog = 0;

int init_font_shader( GLuint_ linked_compiled_prog )
{
    int[ GLuint_.sizeof >= GLuint.sizeof ] size_check;
    cast( void ) size_check;
    the_prog = linked_compiled_prog;
    glUseProgram( the_prog );
    uniforms.the_matrix  = glGetUniformLocation( the_prog, "the_matrix" );
    uniforms.the_color   = glGetUniformLocation( the_prog, "the_color" );
    uniforms.fill_mode   = glGetUniformLocation( the_prog, "fill_mode" );
    uniforms.coord_scale = glGetUniformLocation( the_prog, "coordinate_scale" );
    return 1;
}

void deinit_font_shader() 
{
    glDeleteProgram( the_prog );
}

static void add_glyph_stats( Font *font, SimpleGlyph *glyph, size_t[3] counts, uint[3] limits )
{
    if ( !glyph )
        return;

    if ( IS_SIMPLE_GLYPH( glyph ) ) 
    {
        counts[0] += glyph.tris.num_points_total;
        counts[1] += glyph.tris.num_indices_curve;
        counts[2] += glyph.tris.num_indices_solid;
        limits[0] = ( glyph.tris.num_points_total > limits[0] ) ? glyph.tris.num_points_total : limits[0];
        limits[1] = ( glyph.tris.num_indices_curve > limits[1] ) ? glyph.tris.num_indices_curve : limits[1];
        limits[2] = ( glyph.tris.num_indices_solid > limits[2] ) ? glyph.tris.num_indices_solid : limits[2];
    } 
    else 
    {
        size_t k;
        for( k=0; k < ( glyph.num_parts ); k++ )
        {
            GlyphIndex subglyph_id = cast( uint ) GET_SUBGLYPH_INDEX( glyph, k );
            add_glyph_stats( font, font.glyphs[subglyph_id], counts, limits );
        }
    }
}

static void get_average_glyph_stats( Font* font, uint[3] avg, uint[3] max )
{
    size_t    n;
    size_t[3] total = [0,0,0];
    max[0] = max[1] = max[2] = 0;

    for ( n=0; n<( font.num_glyphs ); n++ )
        add_glyph_stats( font, font.glyphs[n], total, max );

    for ( n=0; n<3; n++ )
        avg[n] = cast(uint) total[n] / font.num_glyphs;
}

void prepare_font( Font* font )
{
    int[ ( font.gl_buffers[0] ).sizeof >= GLuint.sizeof ] size_check;
    GLuint *buf = font.gl_buffers.ptr;
    uint[3] stats;
    uint[3] limits;
    size_t  all_data_size;
    
    cast( void ) size_check;
    
    get_average_glyph_stats( font, stats, limits );
    
    all_data_size  = font.total_points  * PointCoord.sizeof * 2;
    all_data_size += font.total_indices * PointIndex.sizeof;
    all_data_size += font.total_points  * PointFlag.sizeof;
    
    printf(
        "Uploading font to GL\n" ~
        "Average glyph:\n" ~
        "   Points: %u\n" ~
        "   Indices: %u curved, %u solid\n" ~
        "Maximum counts:\n" ~
        "    Points: %u\n" ~
        "    Indices: %u curved, %u solid\n" ~
        "Total memory uploaded to GL: %u bytes\n"
        ,
        stats[0], stats[1], stats[2],
        limits[0], limits[1], limits[2],
        cast( uint ) all_data_size
    );
    
    glUseProgram( the_prog );
    
    glGenVertexArrays( 1, buf );
    glGenBuffers( 3, buf+1 );
    
    glBindVertexArray( buf[0] );
    glEnableVertexAttribArray( ATTRIB_POS );
    glEnableVertexAttribArray( ATTRIB_FLAG );
    glEnableVertexAttribArray( ATTRIB_GLYPH_POS ); /* don't have a VBO for this attribute yet */
    glVertexAttribDivisor( ATTRIB_GLYPH_POS, 1 );
    
    /* point coords & indices */
    glBindBuffer( GL_ARRAY_BUFFER, buf[1] );
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, buf[2] );
    glBufferData( GL_ARRAY_BUFFER, font.total_points * PointCoord.sizeof * 2, font.all_points, GL_STATIC_DRAW );
    glBufferData( GL_ELEMENT_ARRAY_BUFFER, font.total_indices * PointIndex.sizeof, font.all_indices, GL_STATIC_DRAW );
    glVertexAttribPointer( ATTRIB_POS, 2, POINT_COORD_GL_TYPE, GL_FALSE, 0, null );
    
    /* point flags */
    glBindBuffer( GL_ARRAY_BUFFER, buf[3] );
    glBufferData( GL_ARRAY_BUFFER, font.total_points * PointFlag.sizeof, font.all_flags, GL_STATIC_DRAW );
    glVertexAttribIPointer( ATTRIB_FLAG, 1, POINT_FLAG_GL_TYPE, 0, null );
    
    glBindVertexArray( 0 );
    
    /* todo:
    catch out of memory error (although a >32MiB font probably doesn't even exist)
    */
}

void release_font( Font *font )
{
    printf( "Releasing font GL buffers\n" );
    glDeleteVertexArrays( 1, font.gl_buffers.ptr );
    glDeleteBuffers( 3, font.gl_buffers.ptr+1 );
}

void set_text_color( float[4] c ) 
{
    glUniform4fv( uniforms.the_color, 1, c.ptr );
}

static void debug_color( int c )
{
    float[4][] colors = 
    [
        [1.0f, 1.0f, 1.0f, 1.0f],
        [1.0f, 0.0f, 0.0f, 1.0f],
        [0.0f, 0.0f, 1.0f, 1.0f],
        [0.0f, 1.0f, 0.0f, 1.0f],
        [0.6f, 0.6f, 0.6f, 1.0f]
    ];
    c %= colors.sizeof / (colors[0]).sizeof;
    glUniform4fv( uniforms.the_color, 1, colors[c].ptr );
}

void begin_text( Font *font )
{
    glUseProgram( the_prog );
    glUniform1f( uniforms.coord_scale, 1.0f / font.units_per_em );
    debug_color( 0 );
    glBindVertexArray( font.gl_buffers[0] );
}

void end_text()
{
    glBindVertexArray( 0 );
}

static 
void send_matrix( float* matrix )
{
    /* Every instance of the glyph is transformed by the same matrix */
    glUniformMatrix4fv( uniforms.the_matrix, 1, GL_FALSE, matrix );
}

static 
void set_fill_mode( FillMode mode )
{
    static FillMode cur_mode = FILL_SOLID; /* should be set to the same initial value as in the fragment shader code */
    if ( mode == cur_mode ) return;
    cur_mode = mode;
    glUniform1i( uniforms.fill_mode, mode );
}

/* Draws only simple glyphs !! */
static 
void draw_instances( Font *font, size_t num_instances, size_t glyph_index, int flags )
{
    SimpleGlyph *glyph = font.glyphs[ glyph_index ];
    GLint first_vertex;
    FillMode fill_curve=FILL_CURVE, show_flags=SHOW_FLAGS;
    
    if ( glyph.tris.num_points_total == 0 )
        return;
    
    if ( flags & F_ALL_SOLID )
        fill_curve = show_flags = FILL_SOLID;
    
    /* divided by 2 because each point has both X and Y coordinate */
    first_vertex = cast( int ) ( glyph.tris.points - font.all_points ) / 2;
    
    if ( flags & F_DRAW_TRIS )
    {
        size_t offset = ( PointIndex.sizeof * ( glyph.tris.indices - font.all_indices ) );
        uint n_curve = glyph.tris.num_indices_curve;
        uint n_solid = glyph.tris.num_indices_solid;
        
        if ( ( flags & F_DRAW_CURVE ) && n_curve ) 
        {
            if ( flags & F_DEBUG_COLORS )
                debug_color( 1 );
            set_fill_mode( fill_curve );
            glDrawElementsInstancedBaseVertex( GL_TRIANGLES, n_curve, POINT_INDEX_GL_TYPE, cast( void* ) offset, cast( uint ) num_instances, first_vertex );
        }
        
        if ( ( flags & F_DRAW_SOLID ) && n_solid ) 
        {
            if ( flags & F_DEBUG_COLORS )
                debug_color( 4 );
            set_fill_mode( FILL_SOLID );
            glDrawElementsInstancedBaseVertex( GL_TRIANGLES, n_solid, POINT_INDEX_GL_TYPE, cast( void* )( offset + PointIndex.sizeof * n_curve ), cast( uint ) num_instances, first_vertex );
        }
    }
    
    if ( flags & F_DRAW_POINTS )
    {
        if ( flags & F_DEBUG_COLORS ) 
        {
            set_fill_mode( show_flags );
            /* this fill mode causes colors to be generated out of nowhere */
        } 
        else 
        {
            set_fill_mode( FILL_SOLID );
        }
        glDrawArraysInstancedARB( GL_POINTS, first_vertex, glyph.tris.num_points_total, cast( uint ) num_instances );
    }
}

//void glDrawArraysInstancedARB( T )( T mode, int first, sizei count, sizei primcount )
//{
//    glDrawArraysInstanced( mode, first, count, i );
//}
alias glDrawArraysInstancedARB = glDrawArraysInstanced;


version ( ENABLE_COMPOSITE_GLYPHS )
{
static 
void pad_2x2_to_4x4( float[16] out_, float[4] in_ )
{
    memset( out_ + 2, 0, float.sizeof * 14 );
    out_[0]  = in_[0];
    out_[1]  = in_[1];
    out_[4]  = in_[2];
    out_[5]  = in_[3];
    out_[15] = 1;
}

static void compute_subglyph_matrix( float[16] out_, float[4] sg_mat, float[2] sg_offset, float[16] transform )
{
    float[16] a;
    float[16] b;
    float[16] c;
    
    /*
    memcpy( out, transform, sizeof(float)*16 );
    return;
    */
    
    pad_2x2_to_4x4( a, sg_mat );
    mat4_translation( b, -sg_offset[0], -sg_offset[1], 0 );
    mat4_mult( c, a, b );
    mat4_mult( out_, transform, c );
    
    /*
    memcpy( out, transform, sizeof(float)*16 );
    (void) sg_mat;
    (void) sg_offset;
    */
    /* todo */
}

static void draw_composite_glyph( Font* font, void* glyph, size_t num_instances, float[16] global_transform, int flags )
{
    size_t num_parts = GET_SUBGLYPH_COUNT( glyph );
    size_t p;
    
    for( p=0; p < num_parts; p++ )
    {
        GlyphIndex subglyph_index = GET_SUBGLYPH_INDEX( glyph, p );
        SimpleGlyph *subglyph = font.glyphs[ subglyph_index ];
        float *matrix = GET_SUBGLYPH_TRANSFORM( glyph, p );
        float *offset = matrix + 4;
        float[16] m;
        
        if ( !subglyph )
            continue;
        
        compute_subglyph_matrix( m, matrix, offset, global_transform );
        
        if ( subglyph.num_parts == 0 ) 
        {
            send_matrix( m );
            draw_instances( font, num_instances, subglyph_index, flags );
        } 
        else 
        {
            /* composite glyph contains other composite glyphs. At least FreeSans.ttf has these */
            /*
            printf( "A rare case of a recursive composite glyph has been discovered!\n" );
            exit(0);
            */
            draw_composite_glyph( font, subglyph, num_instances, m, flags );
        }
    }
}
} // ENABLE_COMPOSITE_GLYPHS

void bind_glyph_positions( GLuint_ vbo, size_t first )
{
    glBindBuffer( GL_ARRAY_BUFFER, vbo );
    glVertexAttribPointer( ATTRIB_GLYPH_POS, 2, GLYPH_COORD_GL_TYPE, GL_FALSE, 0, cast( void* )( first * 2 * GlyphCoord.sizeof ) );
}

void draw_glyphs( Font* font, float* global_transform, size_t glyph_index, size_t num_instances, int flags )
{
    SimpleGlyph *glyph;
    
    if ( !num_instances )
        return;
    
    glyph = font.glyphs[ glyph_index ];
    
    if ( !glyph || !glyph.tris.num_points_total ) {
        /* glyph has no outline or doesn't even exist */
        return;
    }
    
    if ( IS_SIMPLE_GLYPH( glyph ) ) 
    {
        send_matrix( global_transform );
        draw_instances( font, num_instances, glyph_index, flags );
    } 
    else 
    {
        version ( ENABLE_COMPOSITE_GLYPHS )
        {
            draw_composite_glyph( font, glyph, num_instances, global_transform, flags );
        }
    }
}
