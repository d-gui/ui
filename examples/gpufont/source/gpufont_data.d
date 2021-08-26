module gpufont_data;

import core.stdc.stdint;
import nibtree;
import core.stdc.stdlib : malloc;
import core.stdc.stdlib : free;
import core.stdc.string : memset;
import core.stdc.string : memcpy;

pragma( inline, true )
auto set_cmap_entry( T1, T2, T3 )( T1 font, T2 code, T3 glyph_index ) 
{
    return nibtree_set( &(font).cmap, code, glyph_index );
}

pragma( inline, true )
auto get_cmap_entry( T1, T2 )( T1 font, T2 code ) 
{
    return nibtree_get( &(font).cmap, (code) );
}

/* Must be unsigned integer types: */
alias PointIndex = uint16_t;
alias GlyphIndex = uint32_t;
alias PointFlag  = uint32_t;
/* Can be any types that can represent negative values: */
alias PointCoord = float; /* for contour point coordinates */
alias GlyphCoord = float; /* for glyph instance positions */

/* Glyph outline converted to triangles */
struct GlyphTriangles 
{
    PointCoord* points;           /* 2 floats per point */
    PointFlag*  flags;            /* on-curve flags */
    PointIndex* indices;          /* 1. curve triangles 2. solid triangles */
    uint16_t*   end_points;       /* Straight from TTF. Free'd after triangulation by ttf_file.c */
    uint16_t    num_points_total; /* total number of points, including generated points */
    uint16_t    num_points_orig;  /* number of the original points from TTF file */
    uint16_t    num_indices_total;
    uint16_t    num_indices_curve;
    uint16_t    num_indices_solid;
    uint16_t    num_contours;     /* only used internally */
}

struct SimpleGlyph 
{
    size_t         num_parts; /* if nonzero, then this struct is actually a CompositeGlyph and has no 'tris' field */
    GlyphTriangles tris;
}

/* This is variable-sized and thus can't have an actual type defined.
struct CompositeGlyph {
    size_t num_parts;
    GlyphIndex subglyph_id [num_parts];
    float matrices_and_offsets [num_parts][6]; // first 2x2 matrix, then offset
}
*/

/* Use composite glyphs with these macros: */
pragma( inline, true )
auto GET_SUBGLYPH_COUNT( T )( T com ) 
{
    return *cast( size_t* ) ( com );
}

pragma( inline, true )
auto GET_SUBGLYPH_INDEX( T1, T2 )( T1 com, T2 n ) 
{
    return *cast( GlyphIndex* ) ( cast( size_t* )( com ) + 1 ) + n;
}

pragma( inline, true )
auto GET_SUBGLYPH_TRANSFORM( T1, T2 )( T1 com, T2 n ) 
{
    return ( cast( float* )( cast( GlyphIndex* ) ( cast( size_t* ) ( com ) + 1 ) + GET_SUBGLYPH_COUNT( com ) ) + 6*(n) );
}

/* Returns the size of a composite glyph (in bytes) */
pragma( inline, true )
auto COMPOSITE_GLYPH_SIZE( T )( T num_parts ) 
{
    return ( size_t.sizeof + ( num_parts ) * ( GlyphIndex.sizeof + float.sizeof * 6 ) );
}

/* Composite glyph support can be globally disabled with this macro */
enum ENABLE_COMPOSITE_GLYPHS = 0;

/* Evaluates to true if given SimpleGlyph is really a simple glyph */
pragma( inline, true )
auto IS_SIMPLE_GLYPH( T )( T glyph ) 
{
    return glyph.num_parts == 0;
}

struct LongHorzMetrics
{
    /* Directly from TTF file. They're given in EM units */
    uint16_t adv_width;
    int16_t  lsb;
}

struct Font 
{
    size_t           num_glyphs;      /* how many glyphs the font has */
    uint             units_per_em;    /* used to convert integer coordinates to floats */
    
    SimpleGlyph**    glyphs;          /* Array of pointers to glyphs. Each glyp can be either a SimpleGlyph or a composite glyph */
    void*            all_glyphs;      /* one huge array that contains all SimpleGlyphs and composite glyphs */
    PointCoord*      all_points;      /* a huge array that contains all the points of all simple glyphs */
    PointFlag*       all_flags;       /* all point flags of all simple glyphs */
    PointIndex*      all_indices;     /* all triangle indices of all simple glyphs */
    size_t           total_points;    /* length of all_points and all_flags */
    size_t           total_indices;   /* length of all_indices */
    
    /* Only used by gpufont_draw.c */
    uint32_t[4]      gl_buffers;      /* VAO, point coordinate VBO, IBO, point flag VBO */
    
    /* Maps character codes to glyph indices */
    NibTree          cmap;            /* Encoding could be anything. But its unicode for now */
    
    /* Horizontal metrics in EM units */
    LongHorzMetrics* hmetrics;        /* has one entry for each glyph (unlike TTF file) */
    int              horz_ascender;
    int              horz_descender;
    int              horz_linegap;
}


/* combined platform and platform specific encoding fields */
enum {
    /* Platform 0: Unicode Transformation Format */
    ENC_UTF_DEFAULT  = 0,
    ENC_UTF_11       = 1,
    ENC_UTF_ISO10646 = 2,
    ENC_UTF_20       = 3,
    
    /* Platform 1: Macintosh
    ???
    */
    
    /* Platform 3: Microsoft */
    ENC_MS_SYMBOL    = ( 3 << 16 ),
    ENC_MS_UCS2      = ( 3 << 16 ) | 1, /* Unicode BMP (UCS-2) */
    ENC_MS_SHIFTJIS  = ( 3 << 16 ) | 2,
    ENC_MS_PRC       = ( 3 << 16 ) | 3,
    ENC_MS_BIG5      = ( 3 << 16 ) | 4,
    ENC_MS_WANSUNG   = ( 3 << 16 ) | 5,
    ENC_MS_JOHAB     = ( 3 << 16 ) | 6,
    ENC_MS_UCS4      = ( 3 << 16 ) | 10
}


void destroy_font( Font* font )
{
    if ( font.glyphs )
    {
        if ( font.all_glyphs )
        {
            /* merge_glyph_data has been called */
            free( font.all_glyphs );
            free( font.all_points );
            free( font.all_indices );
            free( font.all_flags );
        }
        else
        {
            /* must delete everything individually */
            size_t n;
            for( n=0; n<font.num_glyphs; n++ )
            {
                SimpleGlyph *g = font.glyphs[n];
                if ( g ) {
                    if ( IS_SIMPLE_GLYPH( g ) ) 
                    {
                        if ( g.tris.end_points ) free( g.tris.end_points );
                        if ( g.tris.indices ) free( g.tris.indices );
                        if ( g.tris.points ) free( g.tris.points );
                        if ( g.tris.flags ) free( g.tris.flags );
                    }
                    free( g );
                }
            }
        }
        free( font.glyphs );
    }
    if ( font.hmetrics )
        free( font.hmetrics );
    memset( font, 0, (*font).sizeof );
}

/* Merges all vertex & index arrays together so that every glyph can be put into the same VBO
Returns 0 if failure, 1 if success */
int merge_glyph_data( Font* font )
{
    GlyphTriangles dummy;
    size_t point_size = ( dummy.points[0] ).sizeof * 2;
    size_t index_size = ( dummy.indices[0] ).sizeof;
    size_t flag_size  = ( dummy.flags[0] ).sizeof;
    
    size_t total_points = 0;
    size_t total_indices = 0;
    size_t total_glyphs_mem = 0;
    char*  all_glyphs=null;
    char*  glyph_p;
    PointCoord* all_points=null;
    PointCoord* point_p;
    PointIndex* all_indices=null;
    PointIndex* index_p;
    PointFlag*  all_flags=null;
    PointIndex* flag_p;
    size_t n;
    
    for( n=0; n<font.num_glyphs; n++ )
    {
        SimpleGlyph *g = font.glyphs[n];
        if ( g )
        {
            if ( IS_SIMPLE_GLYPH( g ) ) 
            {
                total_points += g.tris.num_points_total;
                total_indices += g.tris.num_indices_total;
                total_glyphs_mem += SimpleGlyph.sizeof;
            } 
            else 
            {
                total_glyphs_mem += COMPOSITE_GLYPH_SIZE( g.num_parts );
            }
        }
    }
    
    if ( total_points ) {
        all_points = cast( float* ) malloc( point_size * total_points );
        all_flags  = cast( uint* ) malloc( flag_size * total_points );
        if ( !all_points || !all_flags )
            goto out_of_mem;
    }
    
    if ( total_indices ) {
        all_indices = cast( ushort* ) malloc( index_size * total_indices );
        if ( !all_indices )
            goto out_of_mem;
    }
    
    if ( total_glyphs_mem ) {
        all_glyphs = cast( char* ) malloc( total_glyphs_mem );
        if ( !all_glyphs )
            goto out_of_mem;
    }
    
    point_p = font.all_points  = all_points;
    index_p = font.all_indices = all_indices;
    glyph_p = all_glyphs;
    font.all_glyphs = all_glyphs;
    flag_p  = cast( ushort* ) all_flags;
    font.all_flags = all_flags;
    font.total_indices = total_indices;
    font.total_points = total_points;
    
    for( n=0; n<font.num_glyphs; n++ )
    {
        SimpleGlyph *g = font.glyphs[n];
        if ( g )
        {
            font.glyphs[n] = cast( SimpleGlyph* ) glyph_p;
            
            if ( IS_SIMPLE_GLYPH( g ) )
            {
                size_t np = g.tris.num_points_total;
                size_t ni = g.tris.num_indices_total;
                
                if ( np )
                {
                    memcpy( point_p, g.tris.points, np * point_size );
                    memcpy( flag_p, g.tris.flags, np * flag_size );
                    free( g.tris.points );
                    free( g.tris.flags );
                    g.tris.points = point_p;
                    g.tris.flags  = cast( uint* ) flag_p;
                    point_p += np * 2;
                    flag_p += np;
                }
                
                if ( ni )
                {
                    memcpy( index_p, g.tris.indices, ni * index_size );
                    free( g.tris.indices );
                    g.tris.indices = index_p;
                    index_p += ni;
                }
                
                memcpy( glyph_p, g, SimpleGlyph.sizeof );
                free( g );
                glyph_p += SimpleGlyph.sizeof;
            }
            else
            {
                size_t s = COMPOSITE_GLYPH_SIZE( g.num_parts );
                memcpy( glyph_p, g, s );
                free( g );
                glyph_p += s / ( *glyph_p ).sizeof;
            }
        }
    }
    
    return 1;
    
out_of_mem:
    if ( all_points ) free( all_points );
    if ( all_flags ) free( all_flags );
    if ( all_indices ) free( all_indices );
    if ( all_glyphs ) free( all_glyphs );
    return 0;
}
