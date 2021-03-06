module gpufont_ttf_file;


//#include <stdint.h>
import core.stdc.stdint;
//#include <stdlib.h>
import core.stdc.stdlib;
//#include <stdio.h>
import core.stdc.stdio;
//#include <netinet/in.h> /* ntohl */
//#include <string.h> /* memset */
import core.stdc.string;
//#include "gpufont_data.h"
import gpufont_data;
//#include "ttf_defs.h"
import ttf_defs;
//#include "triangulate.h"
import triangulate;
import ntohs_utils;


//#include "gpufont_ttf_file.h"
enum FontStatus
{
    F_SUCCESS=0,
    F_FAIL_OPEN, /* failed to open file */
    F_FAIL_EOF, /* unexpected end of file */
    F_FAIL_UNK_FILEF, /* unsupported file format */
    F_FAIL_UNSUP_FEA, /* unsupported font feature */
    F_FAIL_UNSUP_VER, /* unsupported version */
    F_FAIL_CORRUPT, /* malformed data */
    F_FAIL_ALLOC, /* out of memory */
    F_FAIL_INCOMPLETE, /* font lacks required information */
    F_FAIL_IMPOSSIBLE, /* should never happen */
    F_FAIL_TRIANGULATE, /* failed to triangulate geometry */
    F_FAIL_BUFFER_LIMIT, /* some statically allocated buffer is too small */
    NUM_FONT_STATUS_CODES
}

//

//#pragma pack(1)
align( 1 ):

alias int8   = int8_t;
alias int16  = int16_t;
alias int32  = int32_t;
alias uint8  = uint8_t;
alias uint16 = uint16_t;
alias uint32 = uint32_t;

enum {
    DEBUG_DUMP    = 1, /* enable/disable level 1 debug messages */
    DEBUG_DUMP2   = 1, /* enable/disable level 2 debug messages */
    ENABLE_OPENMP = 1 /* used for triangulating glyphs. huge speed boost for CJK fonts */
};

/* todo:
- metrics
- support more cmap formats
- proper TTC support
*/

static 
int read_shorts( TCOUNT )( FILE* fp, uint16* x, TCOUNT count )
{
    uint32 n;
    if ( fread( x, 2, count, fp ) != count )
        return 1;
    for ( n=0; n<count; n++ )
        x[n] = ntohs( x[n] );
    return 0;
}

version ( ENABLE_COMPOSITE_GLYPHS )
{
/* Used by read_glyph */
static 
void* read_composite_glyph( FILE* fp, float units_per_em, Font* font, FontStatus[1] status )
{
    /* SubGlyphHeader */
    struct {
        uint16 flags, glyph_index;
    } sgh;
    
    uint16 num = 0; /* temporary counter used to indicate the index of current subglyph in the CompositeGlyph */
    void *glyph_data = null; /* points to a CompositeGlyph, whose size is not yet known */
    
    /* num_subglyphs begins as zero because of calloc */
    glyph_data = calloc( 1, size_t.sizeof );
    
    if ( !glyph_data ) {
        *status = F_FAIL_ALLOC;
        return null;
    }
    
    do {
        int16[2]    args;
        /* These pointers alias glyph_data */
        size_t*     num_subglyphs;
        GlyphIndex* sg_indices;
        float*      sg_matrix;
        float*      sg_offset;
        int16[4]    fixed_matrix;
        int         e;
        
        num_subglyphs = glyph_data;
        *num_subglyphs += 1;
        glyph_data = realloc( glyph_data, COMPOSITE_GLYPH_SIZE( *num_subglyphs ) );
        
        if ( !glyph_data ) {
            *status = F_FAIL_ALLOC;
            return null;
        }
        
        num_subglyphs = glyph_data;
        sg_indices = cast(GlyphIndex*)( num_subglyphs + 1 );
        sg_matrix = cast(float*)( sg_indices + *num_subglyphs ) + num * 6;
        sg_offset = sg_matrix + 4;
        
        if ( read_shorts( fp, &sgh.flags, 2 ) ) {
            *status = F_FAIL_EOF;
            goto error_handler;
        }
        
        if ( sgh.glyph_index >= font.num_glyphs )
            sgh.glyph_index = 0;
        
        sg_indices[ num ] = sgh.glyph_index;
        
        if ( sgh.flags & COM_ARGS_ARE_WORDS ) {
            /* 16-bit args */
            if ( read_shorts( fp, cast(uint16*) args, 2 ) ) {
                *status = F_FAIL_EOF;
                goto error_handler;
            }
        } else {
            /* 8-bit args */
            int8[2] temp;
            if ( fread( temp, 1, 2, fp ) != 2 ) {
                *status = F_FAIL_EOF;
                goto error_handler;
            }
            args[0] = temp[0];
            args[1] = temp[1];
        }
        
        sg_offset[0] = 0;
        sg_offset[1] = 0;
        
        if ( sgh.flags & COM_ARGS_ARE_XY_VALUES ) {
            /* args are an offset vector */
            sg_offset[0] = args[0] / units_per_em;
            sg_offset[1] = args[1] / units_per_em;
        } else {
            /* args are point indices
            todo:
            1. find the GlyphTriangles that corresponds to glyph_index
            2. get coordinates of the relevant points
            
            Either arg1 or arg2 is presumably a point index of the subglyph.
            But the composite glyph has no points of it's own, so what does the other argument refer to???
            */
            cast(void) font;
            printf( "todo: match points\n" );
        }
        
        fixed_matrix[0] = 1;
        fixed_matrix[1] = 0;
        fixed_matrix[2] = 0;
        fixed_matrix[3] = 1;
        
        /* FreeType has "else" between these 3 ifs
        But what if all 3 bits are set? */
        if ( sgh.flags & COM_HAVE_A_SCALE )
        {
            if ( read_shorts( fp, cast(uint16*) fixed_matrix, 1 ) ) {
                *status = F_FAIL_EOF;
                goto error_handler;
            }
            fixed_matrix[3] = fixed_matrix[0];
        }
        else if ( sgh.flags & COM_HAVE_X_AND_Y_SCALE )
        {
            int16[2] temp;
            if ( read_shorts( fp, cast(uint16*) temp, 2 ) ) {
                *status = F_FAIL_EOF;
                goto error_handler;
            }
            fixed_matrix[0] = temp[0];
            fixed_matrix[3] = temp[1];
        }
        else if ( sgh.flags & COM_HAVE_MATRIX )
        {
            if ( read_shorts( fp, cast(uint16*) fixed_matrix, 4 ) ) {
                *status = F_FAIL_EOF;
                goto error_handler;
            }
        }
        
        for( e=0; e<4; e++ )
            sg_matrix[e] = fixed_matrix[e] / cast(float) ( 1 << 14 );
        
        num++;
    } while( sgh.flags & 0x20 );
    
    *status = F_SUCCESS;
    return glyph_data;
    
error_handler:;
    if ( glyph_data )
        free( glyph_data );
    return null;
}
} // ENABLE_COMPOSITE_GLYPHS

static 
int read_contour_coord( FILE* fp, PointFlag flags, int32* co )
{
    uint8 is_short = flags & PT_SHORT_X;
    uint8 is_same = flags & PT_SAME_X;
    if ( is_short ) 
    {
        /* is_same is now the sign; 0x10=positive, 0x00=negative */
        uint8 delta;
        if ( fread( &delta, 1, 1, fp ) != 1 )
            return 0;
        if ( is_same )
            *co += delta;
        else
            *co -= delta;
    } 
    else 
    {
        /* Use the previous coordinate if same_bit is set
        Otherwise, read a 16-bit delta value */
        if ( !is_same ) 
        {
            int16 delta;
            if ( read_shorts( fp, cast(uint16*) &delta, 1 ) )
                return 0;
            *co += delta;
        }
    }
    return 1;
}

/* Used by read_glyph */
static 
SimpleGlyph *read_simple_glyph( FILE* fp, uint16 num_contours, FontStatus* status )
{
    SimpleGlyph *glyph        = null;
    uint16      *end_points   = null;
    PointCoord  *final_points = null;
    uint32      num_points;
    uint32      n;
    int32       prev_coord;
    PointFlag   *final_flags  = null;
    uint16      num_instr;
    
    if ( DEBUG_DUMP2 ) {
        printf( "Reading contour data...\n" );
    }
    
    end_points = cast( typeof( end_points ) ) calloc( num_contours, 2 );
    if ( !end_points ) {
        *status = FontStatus.F_FAIL_ALLOC;
        return null;
    }
    if ( read_shorts( fp, end_points, num_contours ) ) {
        *status = FontStatus.F_FAIL_EOF;
        goto error_handler;
    }
    
    num_points = end_points[ num_contours - 1 ] + 1;
    if ( num_points > MAX_GLYPH_POINTS ) {
        if ( DEBUG_DUMP ) {
            printf( "MAX_GLYPH_POINTS too small (need %u)\n", cast(uint) num_points );
        }
        *status = FontStatus.F_FAIL_BUFFER_LIMIT;
        goto error_handler;
    }
    
    final_flags = cast( typeof( final_flags ) ) malloc( MAX_GLYPH_POINTS * PointFlag.sizeof );
    final_points = cast( typeof( final_points ) )malloc( MAX_GLYPH_POINTS * PointCoord.sizeof * 2 );
    
    if ( !final_points || !final_flags ) {
        *status = FontStatus.F_FAIL_ALLOC;
        goto error_handler;
    }
    
    /* Skip the hinting instruction */
    if ( read_shorts( fp, &num_instr, 1 ) ) {
        *status = FontStatus.F_FAIL_EOF;
        goto error_handler;
    }
    if ( fseek( fp, num_instr, SEEK_CUR ) < 0 ) {
        *status = FontStatus.F_FAIL_CORRUPT;
        goto error_handler;
    }
    
    /* Determine the size of X coordinate array by scanning the flags */
    n = 0;
    while( n < num_points ) 
    {
        uint32 end, count=1;
        uint8 flags;
        
        if ( fread( &flags, 1, 1, fp ) != 1 ) {
            *status = FontStatus.F_FAIL_EOF;
            goto error_handler;
        }
        
        if ( flags & PT_SAME_FLAGS )
        {
            uint8 repeat;
            if ( fread( &repeat, 1, 1, fp ) != 1 ) {
                *status = FontStatus.F_FAIL_EOF;
                goto error_handler;
            }
            count += repeat;
        }
        
        end = n + count;
        
        if ( end > num_points ) {
            /* more flags than points */
            *status = FontStatus.F_FAIL_CORRUPT;
            goto error_handler;
        }
        
        while( n < end )
            final_flags[n++] = flags;
    }
    
    if ( n != num_points ) {
        /* less flags than points */
        *status = FontStatus.F_FAIL_CORRUPT;
        goto error_handler;
    }
    
    /* Read coordinates. First X, then Y */
    *status = FontStatus.F_FAIL_EOF;
    for( prev_coord=n=0; n<num_points; n++ ) {
        int32 x = prev_coord;
        if ( !read_contour_coord( fp, final_flags[n], &x ) )
            goto error_handler;
        final_points[2*n] = prev_coord = x;
    }
    for( prev_coord=n=0; n<num_points; n++ ) {
        int32 y = prev_coord;
        if ( !read_contour_coord( fp, final_flags[n]>>1, &y ) )
            goto error_handler;
        final_points[2*n+1] = prev_coord = y;
        final_flags[n] &= PT_ON_CURVE; /* discard all flags except the one that matters */
    }
    
    glyph = cast( typeof( glyph ) ) calloc( 1, SimpleGlyph.sizeof );
    /* calloc sets glyph.num_parts to 0, which very is important because that zero tells the glyph is not a composite glyph */
    
    if ( !glyph ) {
        *status = FontStatus.F_FAIL_ALLOC;
    } else {
        glyph.tris.num_points_orig = cast( ushort ) num_points;
        glyph.tris.end_points = end_points;
        glyph.tris.points = final_points;
        glyph.tris.flags = final_flags;
        glyph.tris.num_contours = num_contours;
        
        /* these three must not be free'd since they are in use: */
        end_points = null;
        final_points = null;
        final_flags = null;
        
        if ( DEBUG_DUMP2 )
            printf( "Glyph read succesfully\n" );
        
        *status = FontStatus.F_SUCCESS;
    }
    
error_handler:;
    if ( final_points ) free( final_points );
    if ( final_flags ) free( final_flags );
    if ( end_points ) free( end_points );
    
    return glyph;
}

static 
FontStatus read_glyph( FILE* fp, Font* font, uint32 glyph_index, uint32 glyph_file_pos, uint[2] glyph_counts )
{
    /* GlyphHeader */
    struct TStructHeader
    {
        uint16 num_contours;
        int16 xmin, ymin, xmax, ymax;
    }
    TStructHeader header;
    FontStatus status = FontStatus.F_FAIL_IMPOSSIBLE;
    
    if ( fseek( fp, glyph_file_pos, SEEK_SET ) < 0 )
        return FontStatus.F_FAIL_CORRUPT;
    
    if ( read_shorts( fp, &header.num_contours, 5 ) )
        return FontStatus.F_FAIL_EOF;
    
    if ( header.num_contours >= 0x1000 )
    {
        version ( ENABLE_COMPOSITE_GLYPHS )
        {
            font.glyphs[ glyph_index ] = read_composite_glyph( fp, units_per_em, font, &status );
            glyph_counts[1] += ( status == F_SUCCESS );
            
            if ( DEBUG_DUMP2 && font.glyphs[ glyph_index ] ) {
                printf( "Glyph %u is a composite glyph. Has %u components\n", cast(uint) glyph_index, cast(uint) font.glyphs[ glyph_index ].num_parts );
            }
        }
        else // ! ENABLE_COMPOSITE_GLYPHS
        {
            status = FontStatus.F_SUCCESS;
        } 
        
    }
    else
    {
        font.glyphs[ glyph_index ] = read_simple_glyph( fp, header.num_contours, &status );
        glyph_counts[0] += ( status == FontStatus.F_SUCCESS );
    }
    
    return status;
}

/* Reads both 'loca' and 'glyf' tables */
static 
FontStatus read_all_glyphs( FILE* fp, Font* font, int16 format, uint32 glyph_base_offset )
{
    void*      loca_p;
    uint32     n = 0;
    FontStatus status;
    uint[2]    glyph_counts = [0,0];
    
    if ( DEBUG_DUMP )
        printf( "loca format %u (%s)\n", format, format ? "32-bit".ptr : "16-bit".ptr );
    
    if ( format == 0 )
    {
        /* 16-bit glyph location table */
        
        uint16* loca;
        uint16  prev_loc;
        loca = cast( typeof( loca ) ) calloc( font.num_glyphs, 2 );
        loca_p = loca;
        
        if ( !loca )
            return FontStatus.F_FAIL_ALLOC;
        
        if ( read_shorts( fp, loca, font.num_glyphs ) )
            status = FontStatus.F_FAIL_EOF;
        else
        {
            prev_loc = loca[1];
            status = FontStatus.F_FAIL_INCOMPLETE;
            
            for ( n=0; n<font.num_glyphs; n++ )
            {
                uint32 loc = loca[n];
                
                if ( loc == prev_loc ) {
                    /* This glyph has no outline and can be left as null */
                    continue;
                }
                
                if ( DEBUG_DUMP2 )
                    printf( "Reading glyph %u out of %u\n", cast(uint) n, cast(uint) font.num_glyphs );
                
                prev_loc = cast( typeof( prev_loc ) ) loc;
                status = read_glyph( fp, font, n, cast(uint32) loc * 2 + glyph_base_offset, glyph_counts );
                
                if ( status != FontStatus.F_SUCCESS )
                    break;
            }
        }
    }
    else
    {
        /* 32-bit glyph location table */
        
        uint32* loca;
        uint32  prev_loc;
        loca = cast( typeof( loca ) ) calloc( font.num_glyphs, 4 );
        loca_p = loca;
        
        if ( !loca )
            return FontStatus.F_FAIL_ALLOC;
        
        if ( fread( loca, 4, font.num_glyphs, fp ) != font.num_glyphs ) {
            status = FontStatus.F_FAIL_EOF;
        } else {
            prev_loc = loca[1];
            status = FontStatus.F_FAIL_INCOMPLETE;
            
            for( n=0; n<font.num_glyphs; n++ )
            {
                if ( loca[n] == prev_loc )
                    continue;
                
                if ( DEBUG_DUMP2 )
                    printf( "Reading glyph %u out of %u\n", cast(uint) n, cast(uint) font.num_glyphs );
                
                prev_loc = loca[n];
                status = read_glyph( fp, font, n, ntohl( loca[n] ) + glyph_base_offset, glyph_counts );
                
                if ( status != FontStatus.F_SUCCESS )
                    break;
            }
        }
    }
    
    if ( DEBUG_DUMP )
    {
        printf( "Read %u out of %u glyphs\n" ~
            "Simple glyphs: %u\n" ~
            "Composite glyphs: %u\n",
            cast(uint) n,
            cast(uint) font.num_glyphs,
            glyph_counts[0], glyph_counts[1] );
    }
    
    free( loca_p );
    return status;
}

static 
FontStatus read_cmap_format4( FILE* fp, Font* font, uint32 total_length )
{
    uint16 *whole_table;
    uint16 *end_codes;
    uint16 *start_codes;
    uint16 *id_range_offset;
    int16  *id_delta;
    uint16 seg_count;
    uint16 s;
    uint32 max_k;
    uint   total_indices = 0;
    uint   n_valid       = 0;
    
    /* because format and length have been already read */
    total_length -= 2*2;
    
    if ( ( whole_table = cast( typeof( whole_table ) ) malloc( total_length ) ) == null )
        return FontStatus.F_FAIL_ALLOC;
    
    if ( read_shorts( fp, whole_table, total_length >> 1 ) )
        return FontStatus.F_FAIL_EOF;
    
    seg_count = whole_table[1] >> 1;
    end_codes = whole_table + 5;
    start_codes = end_codes + seg_count + 1;
    id_delta = cast(int16*) start_codes + seg_count;
    id_range_offset = start_codes + 2 * seg_count;
    max_k = cast( typeof( max_k ) ) ( total_length / 2 - ( id_range_offset - whole_table ) );
    
    if ( DEBUG_DUMP )
        printf( "Segments: %u\nmax_k=%u\n", cast(uint) seg_count, cast(uint) max_k );
    
    for( s=0; s<seg_count; s++ )
    {
        uint16 c, start, end, stop;
        uint16 idro;
        int16 idde;
        
        end = end_codes[s];
        start = start_codes[s];
        idro = id_range_offset[s];
        idde = id_delta[s];
        stop = cast(typeof(stop)) ( end + 1 );
        total_indices += end - start + 1;
        
        /*
        printf( "start %u end %u idro %u idde %u\n", start, end, idro, idde );
        */
        
        if ( start > end ) {
            free( whole_table );
            return FontStatus.F_FAIL_CORRUPT;
        }
        
        if ( idro != 0 )
        {
            /* glyphIndex = *( &idRangeOffset[i] + idRangeOffset[i] / 2 + (c - startCode[i]) )
            a <= c <= b
            
            glyphIndex = *( &idRangeOffset[i] + idRangeOffset[i] / 2 + (c - startCode[i]) )
            glyphIndex = *( &idRangeOffset[i] + idRangeOffset[i] / 2 + c - startCode[i] )
            glyphIndex = *( idRangeOffset + i + idRangeOffset[i] / 2 + c - startCode[i] )
            glyphIndex = idRangeOffset[ i + idRangeOffset[i] / 2 + c - startCode[i] ]
            */
            
            for ( c=start; c != stop; c++ ) 
            {
                uint16 k = cast( uint16 ) ( idro / 2 + c - start ); /* + s ??? */
                if ( k < max_k )
                {
                    k = id_range_offset[k];
                    if ( k != 0 )
                        n_valid += set_cmap_entry( font, c, ( idde + k ) & 0xFFFF );
                }
            }
        }
        else
        {
            /* glyphIndex = idDelta[i] + c,
            a <= c <= b
            */
            for( c=start; c != stop; c++ )
                n_valid += set_cmap_entry( font, c, ( idde + c ) & 0xFFFF );
        }
    }
    
    if ( DEBUG_DUMP )
    {
        printf( "Success (%u/%u indices set, %u/%u segs)\n", n_valid, total_indices, cast(uint) s, cast(uint) seg_count );
        
        version ( USE_BINTREE_CMAP )
        {
            printf( "Binary tree allocated length: %u\n", font.cmap.data_len );
        }        
    }
    
    free( whole_table );
    return FontStatus.F_SUCCESS;
}

FontStatus read_cmap( FILE *fp, Font *font )
{
    struct THStruct
    {
        uint16 version_; 
        uint16 num_tables; 
    } 
    THStruct h;
    long cmap_header_start = ftell( fp );
    int has_read_cmap = 0;
    FontStatus status = FontStatus.F_FAIL_INCOMPLETE;
    
    if ( read_shorts( fp, &h.version_, 2 ) )
        return FontStatus.F_FAIL_EOF;
    
    if ( h.version_ != 0 )
        return FontStatus.F_FAIL_UNSUP_VER;
    
    cast(void) font.cmap.data_len; /* just to make sure font.cmap is still a NibTree */
    memset( &font.cmap, 0, font.cmap.sizeof );
    
    while( h.num_tables-- )
    {   
        uint32[2] temp;
        uint32 subtable_offset;
        uint32 plat_enc; /* combined platform and specific encoding */
        long next_tabh_pos;
        
        if ( fread( temp.ptr, 4, 2, fp ) != 2 )
            return FontStatus.F_FAIL_EOF;
        
        plat_enc = ntohl( temp[0] );
        subtable_offset = cast( typeof(subtable_offset)) ( cmap_header_start + ntohl( temp[1] ) );
        next_tabh_pos = ftell( fp );
        
        if ( fseek( fp, subtable_offset, SEEK_SET ) < 0 )
            return FontStatus.F_FAIL_CORRUPT;
        else
        {
            struct TQStruct
            { 
                uint16 format; 
                uint16 length; 
            } 
            TQStruct q;
            
            if ( read_shorts( fp, &q.format, 2 ) )
                return FontStatus.F_FAIL_EOF;
            
            if ( DEBUG_DUMP ) {
                printf( "plat_enc = %08x | platform = %u | encoding = %u | offset=%08x | format=%d | length=%d\n",
                    plat_enc, plat_enc >> 16, plat_enc & 0xFFFF, subtable_offset, q.format, q.length );
            }
            
            /* Most common cmap formats seem to be 4 (the most common of all), 6 and 12
                So it seems reasonable to support just format 4 and nothing else */
            
            if ( !has_read_cmap && q.format == 4 )
            {
                status = read_cmap_format4( fp, font, q.length );
                has_read_cmap = 1;
            }
        }
        
        if ( fseek( fp, next_tabh_pos, SEEK_SET ) < 0 )
            return FontStatus.F_FAIL_IMPOSSIBLE;
    }
    
    return status;
}

static 
TrError triangulate_glyphs( Font* font, size_t first_glyph, size_t last_glyph )
{
    size_t n;
    TrError err = TrError.TR_SUCCESS;
    Triangulator* trg;
    
    trg = triangulator_begin();
    
    if ( !trg )
        return TrError.TR_ALLOC_FAIL;
    
    if ( DEBUG_DUMP )
        printf( "Triangulating glyphs [%u ... %u]\n", cast(uint) first_glyph, cast(uint) last_glyph );
    
    for( n=first_glyph; n<=last_glyph; n++ )
    {
        SimpleGlyph *glyph = font.glyphs[n];
        
        if ( glyph && IS_SIMPLE_GLYPH( glyph ))
        {
            err = triangulate_contours( trg, &glyph.tris );
            if ( err != TrError.TR_SUCCESS )
            {
                if ( DEBUG_DUMP )
                    printf( "Triangulation failed. Error code = %u\n", cast(uint) err );
                return err;
            }
            
            free( glyph.tris.end_points );
            glyph.tris.end_points = null;
            glyph.tris.num_contours = 0;
        }
    }
    
    triangulator_end( trg );
    return err;
}

static 
TrError triangulate_all_glyphs( Font* font )
{
    if ( !font.num_glyphs )
        return TrError.TR_SUCCESS;
    
    version ( OPENMP )
    if ( font.num_glyphs > 20 && ENABLE_OPENMP )
    {
        extern uint omp_get_num_procs();
        extern uint omp_get_thread_num();
        size_t n, numt = omp_get_num_procs();
        size_t batch_size = font.num_glyphs / numt;
            
        if ( DEBUG_DUMP )
            printf( "Using %d omp threads\n", cast(uint) numt );
        
        //#pragma omp parallel for
        for( n=0; n<numt; n++ )
        {
            size_t start = n * batch_size;
            size_t end = start + batch_size - 1;
            
            if ( omp_get_thread_num() == numt - 1 )
                end = font.num_glyphs - 1;
            
            triangulate_glyphs( font, start, end );
        }
        
        /* errors ignored when using openmp */
        return TrError.TR_SUCCESS;
    }
    
    return triangulate_glyphs( font, 0, font.num_glyphs - 1 );
}

static 
FontStatus read_hmtx( FILE *fp, Font* font, uint num_hmetrics )
{
    LongHorzMetrics *hmetrics = null;
    FontStatus status;
    
    int[ (*hmetrics).sizeof == 4 ] size_test;
    cast(void) size_test;
    
    if ( font.num_glyphs == 0 )
        return FontStatus.F_SUCCESS;
    
    hmetrics = cast(typeof(hmetrics)) malloc( font.num_glyphs * 4 );
    if ( !hmetrics )
        return FontStatus.F_FAIL_ALLOC;
    
    status = FontStatus.F_FAIL_EOF;
    if ( read_shorts( fp, &hmetrics[0].adv_width, 2 * num_hmetrics ) )
        goto error_handler;
    
    if ( num_hmetrics < font.num_glyphs )
    {
        uint16 last_adv_x = hmetrics[ num_hmetrics - 1 ].adv_width;
        size_t n, num_lsb, end;
        
        num_lsb = font.num_glyphs - num_hmetrics;
        end = num_hmetrics + num_lsb;
        status = FontStatus.F_FAIL_EOF;
        
        for( n=num_hmetrics; n<end; n++ )
        {
            int16 lsb;
            if ( fread( &lsb, 2, 1, fp ) != 1 )
                goto error_handler;
            hmetrics[n].adv_width = last_adv_x;
            hmetrics[n].lsb = ntohs( lsb );
        }
    }
    
    font.hmetrics = hmetrics;
    return FontStatus.F_SUCCESS;
    
error_handler:;
    free( hmetrics );
    return status;
}

/* Assumes that the file is positioned after the very first field of Offset Table (sfnt version) */
static FontStatus read_offset_table( FILE *fp, Font* font )
{
    /* Indices of the tables we are interested in.
    table_pos and table_len are accessed with these  */
    enum {
        TAB_HEAD=0,
        TAB_MAXP,
        TAB_LOCA,
        TAB_GLYF,
        TAB_CMAP,
        TAB_HHEA,
        TAB_HMTX,
    /*
        TAB_VHEA,
        TAB_VMTX,
    */
        NUM_USED_TABLES
    }
    
    uint32[NUM_USED_TABLES] table_pos;
    uint16 n, num_tables, num_glyphs;
    HeadTable head = {0};
    MaxProTableOne maxp = {0};
    HorzHeaderTable hhea = {0};
    FontStatus status;
    
    if ( read_shorts( fp, &num_tables, 1 ) )
        return FontStatus.F_FAIL_EOF;
    
    /* Skip rest of the offset table header */
    if ( fseek( fp, 3*2, SEEK_CUR ) < 0 )
        return FontStatus.F_FAIL_EOF;
    
    for( n=0; n<num_tables; n++ )
    {
        /* TableRecord */
        struct TRec {
            uint32 tag;
            uint32 checksum;
            uint32 file_offset;
            uint32 length;
        }
        TRec rec;
        int tab_num;
        
        if ( fread( &rec, 4, 4, fp ) != 4 )
            return FontStatus.F_FAIL_EOF;
        
        /* todo: remove this ntohl and convert the constants instead */
        switch( ntohl( rec.tag ) ) {
            case 0x68656164: tab_num = TAB_HEAD; break;
            case 0x6d617870: tab_num = TAB_MAXP; break;
            case 0x6c6f6361: tab_num = TAB_LOCA; break;
            case 0x676c7966: tab_num = TAB_GLYF; break;
            case 0x636d6170: tab_num = TAB_CMAP; break;
            case 0x68686561: tab_num = TAB_HHEA; break;
            case 0x686d7478: tab_num = TAB_HMTX; break;
            default:
                if ( DEBUG_DUMP )
                {
                    /* todo */
                    printf( "unsupported table: %.4s\n", cast(char*) &rec.tag );
                }
                continue;
        }
        
        table_pos[ tab_num ] = ntohl( rec.file_offset );
        /* table_len[ tab_num ] = ntohl( rec.length ); */
        /* todo: verify checksum */
    }
    
    for( n=0; n<NUM_USED_TABLES; n++ ) {
        if ( !table_pos[n] ) {
            /* Missing important tables */
            return FontStatus.F_FAIL_INCOMPLETE;
        }
    }
    
    /* Read table: "head" */
    if ( fseek( fp, table_pos[TAB_HEAD], SEEK_SET ) < 0 )
        return FontStatus.F_FAIL_CORRUPT;
    if ( fread( &head, 54, 1, fp ) != 1 )
        return FontStatus.F_FAIL_EOF;
    if ( head.magic != htonl( 0x5F0F3CF5 ) )
        return FontStatus.F_FAIL_CORRUPT;
    
    /* Read table: "maxp" */
    if ( fseek( fp, table_pos[TAB_MAXP], SEEK_SET ) < 0 )
        return FontStatus.F_FAIL_CORRUPT;
    if ( fread( &maxp, 6, 1, fp ) != 1 )
        return FontStatus.F_FAIL_EOF;
    if ( maxp.version_ == htonl( 0x5000 ) ) {
        /* maxp version 0.5 */
    } else if ( maxp.version_ == htonl( 0x10000 ) ) {
        /* maxp version 1.0 */
        if ( fread( &maxp.max_points, 26, 1, fp ) != 1 )
            return FontStatus.F_FAIL_EOF;
    } else {
        /* unsupported maxp version */
        return FontStatus.F_FAIL_UNSUP_VER;
    }
    
    num_glyphs = ntohs( maxp.num_glyphs );
    font.units_per_em = ntohs( head.units_per_em );
    
    if ( DEBUG_DUMP )
    {
        printf(
            "Font statistics:\n" ~
            "Version: %08x\n" ~
            "Revision: %08x\n" ~
            "Tables: %hu\n" ~
            "head / Flags: %08hx\n" ~
            "head / Units per EM: %u\n" ~
            "maxp 0.5 / Glyphs: %u\n"
            , 
            cast ( uint ) ntohl( head.version_ ),
            cast ( uint ) ntohl( head.font_rev ),
            cast ( ushort ) num_tables,
            ntohs( head.flags ),
            font.units_per_em,
            cast( uint ) num_glyphs );
        if ( maxp.version_ == htonl( 0x10000 ) )
        {
            printf(
            "maxp 1.0 / Max contours %hu\n" ~
            "maxp 1.0 / Max points (simple glyph) %hu\n" ~
            "maxp 1.0 / Max contours (simple glyph) %hu\n" ~
            "maxp 1.0 / Max composite recursion %hu\n",
            ntohs( maxp.max_contours ),
            ntohs( maxp.max_points ),
            ntohs( maxp.max_contours ),
            ntohs( maxp.max_com_recursion ) );
        }
    }
    
    font.num_glyphs = num_glyphs;
    if (( ( font.glyphs = cast(typeof(font.glyphs)) calloc( num_glyphs, font.glyphs[0].sizeof ) ) == null )) 
        return FontStatus.F_FAIL_ALLOC;
    
    if ( fseek( fp, table_pos[TAB_LOCA], SEEK_SET ) < 0 )
        return FontStatus.F_FAIL_CORRUPT;
    
    /* Read glyph contours using tables "loca" and "glyf" */
    status = read_all_glyphs( fp, font, head.index_to_loc_format, table_pos[TAB_GLYF] );
    if ( status != FontStatus.F_SUCCESS )
        return status;
    
    /* Read table "cmap" */
    if ( fseek( fp, table_pos[TAB_CMAP], SEEK_SET ) < 0 )
        return FontStatus.F_FAIL_CORRUPT;
    status = read_cmap( fp, font );
    if ( status != FontStatus.F_SUCCESS )
        return status;
    
    /* Read horizontal metrics header */
    if ( fseek( fp, table_pos[TAB_HHEA], SEEK_SET ) < 0 )
        return FontStatus.F_FAIL_CORRUPT;
    if ( fread( &hhea, hhea.sizeof, 1, fp ) != 1 )
        return FontStatus.F_FAIL_EOF;
    if ( hhea.version_ != htonl( 0x10000 ) )
        return FontStatus.F_FAIL_UNSUP_VER;
    if ( hhea.metric_data_format )
        return FontStatus.F_FAIL_UNSUP_VER;
    
    font.horz_ascender = cast( int16 ) ntohs( hhea.ascender );
    font.horz_descender = cast( int16 ) ntohs( hhea.descender );
    font.horz_linegap = cast( int16 ) ntohs( hhea.linegap );
    
    /* Read horizontal metrics */
    if ( fseek( fp, table_pos[TAB_HMTX], SEEK_SET ) < 0 )
        return FontStatus.F_FAIL_CORRUPT;
    status = read_hmtx( fp, font, ntohs( hhea.num_hmetrics ) );
    if ( status != FontStatus.F_SUCCESS )
        return status;
    
    /* todo:
    
    handle errors properly
    
    for each glyph:
        read location from the 'loca' table
        read glyph data
        group curves into triangles
        subdivide overlapping triangles
        generate solid triangles to fill the glyph interior
    create VBOs
    for each glyph:
        upload VBO data
    read cmap
    read hhead, hmtx (horizontal metrics)
    read vhea, vmtx (vertical metrics)
    
    Other useful tables:
    BASE - baseline data. Needed to mix glyphs from different scripts (e.g. some math symbols and CJK)
    GDEF, GPOS - used to change position of glyphs based on context
    GSUB - used to replace glyphs based on context
    JSTF - additional positioning crap
    post - has some interesting fields: italicAngle, underlinePosition, underlineThickness, isFixedPitch
    kern - glyph positioning. same as GPOS but less useful?
    name - font name & family name
    */
    
    return FontStatus.F_SUCCESS;
}

static FontStatus read_ttc( FILE* fp, Font* font )
{
    /* the tag "ttcf" has been already consumed */
    uint32[3] h;
    
    if ( fread( h.ptr, 4, 3, fp ) != 3 )
        return FontStatus.F_FAIL_EOF;
    
    if ( h[0] != htonl( 0x10000 ) && h[0] != htonl( 0x20000 ) ) {
        /* unsupported TTC version */
        return FontStatus.F_FAIL_UNSUP_VER;
    }
    
    if ( h[1] == 0 ) {
        /* TTC doesn't contain any fonts. Still a valid TTC though? */
        return FontStatus.F_FAIL_INCOMPLETE;
    }
    
    /*
    The font has at least 1 font
    - todo: read more than 1 font
    */
    if ( fseek( fp, ntohl( h[2] )+4, SEEK_SET ) < 0 ) {
        return FontStatus.F_FAIL_CORRUPT;
    }
    
    return read_offset_table( fp, font );
}

FontStatus load_ttf_file( Font* font, immutable(char*) filename )
{
    FILE *fp = null;
    uint32 file_ident;
    FontStatus status;
    
    memset( font, 0, (*font).sizeof );
    fp = fopen( filename, "rb" );
    
    if ( !fp )
        return FontStatus.F_FAIL_OPEN;
    
    if ( fread( &file_ident, 4, 1, fp ) != 1 ) {
        status = FontStatus.F_FAIL_EOF;
    } else {
        version ( USE_SDL_TIMING )
        {
            extern uint32 SDL_GetTicks( void );
            uint32 t = SDL_GetTicks();
        } // USE_SDL_TIMING
        
        if ( file_ident == htonl( 0x10000 ) ) {
            /* This is a TrueType font file (sfnt version 1.0)
            todo: handle other identifiers ("true", "typ1", "OTTO") */
            status = read_offset_table( fp, font );
        } else if ( file_ident == *cast(uint32*)"ttcf" ) {
            /* Is a TrueType Collection */
            status = read_ttc( fp, font );
        } else {
            /* Unsupported file format */
            status = FontStatus.F_FAIL_UNK_FILEF;
        }
        
        if ( status == FontStatus.F_SUCCESS )
        {
            version ( USE_SDL_TIMING )
            {
                t = SDL_GetTicks() - t;
                printf( "File I/O took %u milliseconds\n", cast(uint) t );
            } // USE_SDL_TIMING
            
            if ( triangulate_all_glyphs( font ) != TrError.TR_SUCCESS )
                status = FontStatus.F_FAIL_TRIANGULATE;
            
            /* Merges contour points, indices and glyph data into large contiguous blocks of memory */
            if ( !merge_glyph_data( font ) )
                status = FontStatus.F_FAIL_ALLOC;
        }
    }
    
    fclose( fp );
    return status;
}
