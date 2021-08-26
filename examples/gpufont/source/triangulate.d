module triangulate;

// #include <stdlib.h>
import core.stdc.stdlib;
// #include <string.h>
import core.stdc.string;
//#include <assert.h>
//#include <math.h>
import core.stdc.math;
//#include <stdint.h>
import core.stdc.stdint;
//#include <GL/glu.h>
import deps.gl3;
import derelict.opengl.glu;

//version ( windows )
//    pragma( lib, "Glu32.lib" );
//version ( linux )
//    pragma( lib, "glut" );

//#include "gpufont_data.h"
import gpufont_data;
//#include "ttf_defs.h"
import ttf_defs;
//#include "linkedlist.h"
import linkedlist;

enum ENABLE_SUBDIV = 0;
enum DEBUG_DUMP =  1;

version ( DEBUG_DUMP )
{
    import core.stdc.stdio;
}


/* memory limits */
enum {
    MAX_GLYPH_CONTOURS = 128, /* Max contours per glyph (FreeMono.ttf has 120) */
    //MAX_GLYPH_POINTS = 2048, /* Max total per (simple) glyph (FreeMono.ttf has up to 480). Includes generated points */
    MAX_GLYPH_POINTS = 4096, /* Max total per (simple) glyph (FreeMono.ttf has up to 480). Includes generated points */
    MAX_GLYPH_TRI_INDICES = 4096 /* Max triangle indices */
}

/* error codes */
enum TrError {
    TR_SUCCESS=0,
    TR_POINTS_LIMIT, /* too many points */
    TR_INDICES_LIMIT, /* too many indices */
    TR_ALLOC_FAIL /* calloc/malloc failed */
}

/* Before calling triangulate_contours()
gt.end_points must not be null
gt.points must be allocated to 2*MAX_GLYPH_POINTS elements
gt.flags must be allocated to MAX_GLYPH_POINTS elements
Other fields in gt must also have been initialized
*/

//
struct Contour
{
    LinkedList points;
    int        clockwise; /* 1 if clockwise, 0 if counter-clockwise */
    int        convex; /* 1 if convex, 0 if concave */
    int        is_hole;
}

alias uint16 = uint16_t;

pragma( inline, true )
auto subs_vec2( T1, T2, T3 )( T1 c, T2 a, T3 b) 
{ 
    c[0] = a[0] - b[0]; 
    c[1] = a[1] - b[1]; 
}

pragma( inline, true )
auto cross2( T1, T2 )( T1 a, T2 b ) 
{
    return a[0] * b[1] - a[1] * b[0];
}

pragma( inline, true )
auto average2( T1, T2, T3 )( T1 c, T2 a, T3 b ) 
{ 
    c[0] = ( a[0] + b[0] ) / 2; 
    c[1] = ( a[1] + b[1] ) / 2; 
}

static 
PointCoord ac_cross_ab( PointCoord* a, PointCoord* b, PointCoord* c )
{
    PointCoord[2] ab;
    PointCoord[2] ac;
    subs_vec2( ab, b, a );
    subs_vec2( ac, c, a );
    return cross2( ac, ab );
}

static 
int any_point_in_triangle( PointCoord* coords, size_t num_points, PointCoord* a, PointCoord* b, PointCoord* c )
{
    double[2]   ab;
    double[2]   bc;
    double[2]   ca;
    double[3]   q;
    double[3]   w;
    size_t      n;
    PointCoord* temp;
    
    /* Sort a,b,c by y coordinate such that a[1] <= b[1] <= c[1] */
    if ( a[1] > b[1] ) 
    {
        temp = b;
        b    = a;
        a    = temp;
    }
    if ( a[1] > c[1] ) 
    {
        temp = c;
        c    = b;
        b    = a;
        a    = temp;
    }
    if ( b[1] > c[1] ) 
    {
        temp = c;
        c    = b;
        b    = temp;
    }
    
    assert( a[1] <= b[1] );
    assert( a[1] <= c[1] );
    assert( b[1] <= c[1] );
    
    /* Precompute stuff */
    subs_vec2( ab, b, a );
    subs_vec2( bc, c, b );
    subs_vec2( ca, a, c );
    q[0] = ab[0] / ab[1];
    w[0] = a[0] - ab[0] * a[1] / ab[1];
    q[1] = bc[0] / bc[1];
    w[1] = b[0] - bc[0] * b[1] / bc[1];
    q[2] = ca[0] / ca[1];
    w[2] = c[0] - ca[0] * c[1] / ca[1];
    
    /* If ab[1] == 0, then a[1]==b[1]
    And because must be p[1] > a[1] for the collision test to happen, NaNs from q[0] and w[0] won't be even touched
    Same goes for q[1] and w[1]
    */
    
    if ( ca[1] == 0 ) 
    {
        /* All points lie on an line parallel to x axis, thus all effort would be futile */
        return 0;
    }
    
    for( n=0; n<num_points; n++ )
    {
        PointCoord* p = coords + 2 * n;
        int hits;
        
        if ( p[1] > a[1] && p[1] < c[1] )
        {
            hits = ( p[1] * q[2] + w[2] > p[0] );
            
            if ( p[1] < b[1] )
                hits += ( p[1] * q[0] + w[0] > p[0] );
            else
                hits += ( p[1] * q[1] + w[1] > p[0] );
            
            if ( hits == 1 )
            {
                /* p != a because p[1] > a[1]
                and p != c because p[1] < c[1] */
                if ( p != b )
                    return 1;
            }
        }
    }
    
    return 0;
}

static 
void merge_extra_verts( Contour* co, PointCoord* coords, PointFlag* flags, size_t num_orig_points )
{
    struct TNodesStruct
    {
        LLNodeID a, b, c, d, e;
        LLNodeID f, g;
    }
    TNodesStruct nodes;
    
    if ( co.points.length < 5 )
        return;
    
    nodes.c = co.points.root;
    do {
        nodes.b = LL_PREV( co.points, nodes.c );
        nodes.d = LL_NEXT( co.points, nodes.c );
        nodes.a = LL_PREV( co.points, nodes.b );
        nodes.e = LL_NEXT( co.points, nodes.d );
        
        if (
            ( flags[nodes.a] & PT_ON_CURVE )
            && !( flags[nodes.b] & PT_ON_CURVE )
            && ( flags[nodes.c] & PT_ON_CURVE ) 
        )
        {
            PointCoord* a;
            PointCoord* b;
            PointCoord* c;
            PointCoord[2] ab; /* , bc[2]; */
            
            a = coords + 2 * nodes.a;
            b = coords + 2 * nodes.b;
            c = coords + 2 * nodes.c;
            
            subs_vec2( ab, b, a );
            /* subs_vec2( bc, c, b ); */
            
            /* Subdivide overlapping triangles */
            if ( any_point_in_triangle( coords, num_orig_points, a, b, c ) )
            {
                PointCoord* f;
                PointCoord* g;
                
                nodes.f = add_node( &co.points, nodes.b );
                if ( nodes.f == LL_BAD_INDEX )
                    return;
                
                nodes.g = add_node( &co.points, nodes.c );
                if ( nodes.g == LL_BAD_INDEX ) {
                    pop_node( &co.points, nodes.f );
                    return;
                }
                
                f = coords + 2 * nodes.f;
                g = coords + 2 * nodes.g;
                
                average2( f, a, b );
                average2( g, c, b );
                average2( b, f, g );
                
                flags[ nodes.f ] = 0;
                flags[ nodes.g ] = 0;
                flags[ nodes.b ] = PT_ON_CURVE;
            }
            else
            /* Delete redudant points */
            if ( !( flags[nodes.d] & PT_ON_CURVE ) && ( flags[nodes.e] & PT_ON_CURVE ) && ENABLE_SUBDIV )
            {
                /* We have found a on-OFF-on-OFF-on sequence
                If B,C,D are on the same side of line AE, then it is possible to remove B and D without changing the geometry
                Also, the resulting triangle ACE must not overlap with other geometry (or many glitches happens)
                */
                
                PointCoord[2] ae;
                PointCoord[2] ad;
                PointCoord[2] ed;
                PointCoord*   d;
                PointCoord*   e;
                int           sign1, sign2;
                
                d = coords + 2 * nodes.d;
                e = coords + 2 * nodes.e;
                
                subs_vec2( ae, e, a );
                subs_vec2( ad, d, a );
                /* subs_vec2( bd, d, b ); */
                subs_vec2( ed, d, e );
                
                sign1 = cross2( ae, ab ) <= 0;
                sign2 = cross2( ae, ad ) <= 0;
                /* sign3 = cross2( bd, bc ) <= 0; */
                
                /* ( b and d lie on the same side of line ae ) && ( c lies on that very same side of line bd ) */
                if ( sign1 == sign2 )
                {
                    const PointCoord epsilon = 0.0001;
                    PointCoord[2] p;
                    
                    average2( p, b, d );
                    subs_vec2( p, p, c );
                    
                    if ( p[0]*p[0] + p[1]*p[1] < epsilon*epsilon )
                    {
                        /* c lies approximately halfway trough between b and d */
                        
                        PointCoord w;
                        w = e[0] + ed[0] * a[1] - ed[0] * e[1] - ed[1] * a[0];
                        w /= ed[1] * ab[0] - ed[0] * ab[1];
                        p[0] = a[0] + w * ab[0];
                        p[1] = a[1] + w * ab[1];
                        
                        if ( !any_point_in_triangle( coords, num_orig_points, a, p.ptr, e ) )
                        {
                            c[0] = p[0];
                            c[1] = p[1];
                            flags[ nodes.c ] = 0;
                            pop_node( &co.points, nodes.b );
                            pop_node( &co.points, nodes.d );
                        }
                    }
                    
                    /**
                    P = The position where B,C,D could be merged
                1)  P = A + w * AB
                2)  P = E + g * ED
                    
                    A + w*AB = E + g*ED
                    
                    Components:
                3)  a[0] + w * ab[0] = e[0] + g * ed[0]
                4)  a[1] + w * ab[1] = e[1] + g * ed[1]
                    
                    Solve g from equation 4):
                    a[1] + w * ab[1] = e[1] + g * ed[1]
                    a[1] + w * ab[1] - e[1] = g * ed[1]
                    ( a[1] + w * ab[1] - e[1] ) / ed[1] = g
                    
                    Plug that g to equation 3):
                    a[0] + w * ab[0] = e[0] + { ( a[1] + w * ab[1] - e[1] ) / ed[1] } * ed[0]
                    a[0] + w * ab[0] = e[0] + { ed[0] * ( a[1] + w * ab[1] - e[1] ) } / ed[1]
                    a[0] + w * ab[0] = e[0] + { ed[0] * a[1] + ed[0] * w * ab[1] - ed[0] * e[1] } / ed[1]
                    ed[1] * a[0] + ed[1] * w * ab[0] = e[0] + { ed[0] * a[1] + ed[0] * w * ab[1] - ed[0] * e[1] }
                    ed[1] * a[0] + ed[1] * w * ab[0] = e[0] + ed[0] * a[1] + ed[0] * w * ab[1] - ed[0] * e[1]
                    ed[1] * w * ab[0] - ed[0] * w * ab[1] = e[0] + ed[0] * a[1] - ed[0] * e[1] - ed[1] * a[0]
                    w * ( ed[1] * ab[0] - ed[0] * ab[1] ) = e[0] + ed[0] * a[1] - ed[0] * e[1] - ed[1] * a[0]
                    w = { e[0] + ed[0] * a[1] - ed[0] * e[1] - ed[1] * a[0] } / { ed[1] * ab[0] - ed[0] * ab[1] }
                    
                    Now compute w and then obtain P from equation 1)
                    **/
                }
            }
        }
        
        nodes.c = LL_NEXT( co.points, nodes.c );
    } while( nodes.c != co.points.root );
}

/* The contour must have at least 1 point */
static 
TrError split_consecutive_off_curve_points( Contour* co, PointCoord* coords, PointFlag* flags )
{
    LLNodeID a;
    LLNodeID start;
    a = start = co.points.root;
    do {
        LLNodeID b = LL_NEXT( co.points, a );
        
        if ( !( flags[a] & PT_ON_CURVE ) && !( flags[b] & PT_ON_CURVE ) )
        {
            PointCoord *coord_a = coords + 2*a;
            PointCoord *coord_b = coords + 2*b;
            
            LLNodeID c = add_node( &co.points, b ); /* add a node between a & b */
            
            if ( c == LL_BAD_INDEX ) {
                /* can't add more points */
                return TrError.TR_POINTS_LIMIT;
            }
            
            assert( c < MAX_GLYPH_POINTS );
            assert( LL_NEXT( co.points, a ) == c );
            assert( LL_PREV( co.points, b ) == c );
            
            average2( coords + 2*c, coord_a, coord_b );
            flags[c] = PT_ON_CURVE;
        }
        
        a = b;
    } while( a != start );
    return TrError.TR_SUCCESS;
}

static 
PointCoord get_signed_polygon_area( PointCoord* coords, size_t num_points )
{
    size_t     a=0;
    size_t     b=1;
    PointCoord area = 0;
    
    if ( num_points < 3 )
        return 0;
    
    do {
        PointCoord* p0 = coords + 2 * a;
        PointCoord* p1 = coords + 2 * b;
        
        area += p0[0] * p1[1] - p1[0] * p0[1];
        
        a = b;
        b = ( b + 1 ) % num_points;
    } while( a );
    
    return area;
}

static 
int point_in_polygon( PointCoord* coords, size_t num_points, PointCoord* p )
{
    size_t p0=0, p1=1;
    int inside = 0;
    
    if ( num_points < 3 )
        return 0;
    
    do {
        PointCoord *a;
        PointCoord *b;
        a = coords + 2 * p0;
        b = coords + 2 * p1;
        
        /* There is an intersection if points a and b lie on different sides of the horizontal line y=p[1] */
        if (( a[1] <= p[1] && b[1] > p[1] ) || ( a[1] > p[1] && b[1] <= p[1] ))
        {
            /* the condition above avoids division by zero when b[1]==a[1] */
            inside ^= ( p[1] - a[1] ) * ( b[0] - a[0] ) / ( b[1] - a[1] ) + ( a[0] ) < p[0];
        }
        
        p0 = p1;
        p1 = ( p1 + 1 ) % num_points;
    } while( p0 );
    
    return inside;
}

struct MyGLUCallbackArg 
{
    PointCoord* coords;
    PointFlag*  flags;
    LinkedList* newpts;
    PointIndex* ptr; /* index output array */
    size_t      num; /* number of indices */
    uint16*     num_points_total;
}

static 
void glu_combine_callback( GLdouble* co, size_t* input, GLfloat* weight, size_t* output, MyGLUCallbackArg* p )
{
    LLNodeID node = add_node( p.newpts, LL_BAD_INDEX );
    if ( node == LL_BAD_INDEX ) 
    {
        version ( DEBUG_DUMP )
        {
            printf( "GLU combine callback: not enough memory\n" );
        }
        exit( 79 );
    }
    p.coords[ 2 * node ] = co[0];
    p.coords[ 2 * node + 1 ] = co[1];
    p.flags[ node ] = PT_ON_CURVE;
    output[0] = node;
    
    if ( node+1 > p.num_points_total[0] )
        p.num_points_total[0] = cast( typeof( p.num_points_total[0] )) ( node+1 );
    
    cast(void) weight;
    cast(void) input;
}

static 
void glu_vertex_callback( size_t index, MyGLUCallbackArg *p ) 
{
    if ( p.num < MAX_GLYPH_TRI_INDICES )
        p.ptr[ p.num++ ] = cast(ushort) index;
}

version ( DEBUG_DUMP )
{
    static void glu_error_handler( GLenum code )
    {
        static int rep = 0;
        if ( rep < 15 ) 
        {
            rep++;
            printf( "GLU error callback: %d\n", code );
        }
    }
}

struct Triangulator 
{
    GLUtesselator*                       tess;
    GLdouble[MAX_GLYPH_TRI_INDICES+1][2] glu_coords;
}

Triangulator* triangulator_begin()
{
    GLUtesselator* handle = null;
    Triangulator*  trgu;
    
    /* trgu.glu_coords needs to be zero-initialized (otherwise GLU goes use uninitialized z coordinates)
    hence the need for calloc */
    
    trgu = cast( typeof( trgu ) ) calloc( 1, (*trgu).sizeof );
    if ( !trgu )
        return null;
    
    handle = gluNewTess();
    if ( !handle ) 
    {
        free( trgu );
        return null;
    }
    
    /* Registering an edge flag callback prevents GLU from outputting triangle fans and strips
    (even if all the callback does is to compute the absolute value of it's argument)
    */
    
    version ( DEBUG_DUMP )
    {
        gluTessCallback( handle, GLU_TESS_ERROR, cast(_GLUfuncptr) glu_error_handler );
    }
    
    gluTessCallback( handle, GLU_TESS_COMBINE_DATA, cast(_GLUfuncptr) &glu_combine_callback );
    gluTessCallback( handle, GLU_TESS_VERTEX_DATA, cast(_GLUfuncptr) &glu_vertex_callback );
    gluTessCallback( handle, GLU_TESS_EDGE_FLAG, cast(_GLUfuncptr) &abs );
    gluTessProperty( handle, GLU_TESS_BOUNDARY_ONLY, GL_FALSE );
    gluTessProperty( handle, GLU_TESS_WINDING_RULE, GLU_TESS_WINDING_NONZERO );
    gluTessNormal( handle, 0, 0, 1 );
    
    trgu.tess = handle;
    return trgu;
}

void triangulator_end( Triangulator* trgu )
{
    assert( trgu );
    assert( trgu.tess );
    gluDeleteTess( trgu.tess );
    free( trgu );
}

TrError triangulate_contours( Triangulator* trgu, GlyphTriangles* gt )
{
    uint16      num_contours = gt.num_contours;
    PointFlag*  point_flags  = gt.flags;
    PointCoord* point_coords = gt.points;
    uint16*     end_points   = gt.end_points;
    
    size_t num_tris_curve = 0;
    size_t num_tris_solid = 0;
    PointIndex *tri_indices = null;
    
    LLNode[MAX_GLYPH_POINTS]    node_pool;
    Contour[MAX_GLYPH_CONTOURS] con;
    uint16     start=0; 
    uint16     end;
    uint16     c;
    LinkedList new_points_list;
    
    gt.num_points_total = 0;
    gt.end_points       = end_points;
    gt.points           = point_coords;
    gt.flags            = point_flags;
    
    /* all contours share the same "empty" list, which begins after the last original point */
    init_list( &new_points_list, node_pool.ptr, gt.num_points_orig, MAX_GLYPH_POINTS - 1 );
    
    /* Construct a linked list for each contour */
    for( c=0; c<num_contours; c++ )
    {
        Contour *c1 = con.ptr + c;
        uint16 d;
        uint16 d_start, d_end;
        uint16 count;
        TrError err;
        
        end = end_points[c];
        if ( end >= MAX_GLYPH_POINTS )
            return TrError.TR_POINTS_LIMIT;
        
        count = cast( ushort ) ( end - start + 1 );
        
        init_list( &c1.points, node_pool.ptr, start, end );
        c1.points.root = start;
        c1.points.free_root_p = &new_points_list.free_root;
        c1.points.length = count;
        c1.is_hole = 0;
        c1.clockwise = 0;
        
        /* Detect vertex winding */
        c1.clockwise = get_signed_polygon_area( point_coords + 2 * start, end - start + 1 ) < 0;
        
        /* Make sure that there are no multiple consecutive off-curve points anywhere
        (new points may be added) */
        err = split_consecutive_off_curve_points( con.ptr+c, point_coords, point_flags );
        if ( err != TrError.TR_SUCCESS )
            return err;
        
        /* This function fixes nasty geometry
        (points may be moved, deleted or added) */
        merge_extra_verts( con.ptr+c, point_coords, point_flags, gt.num_points_orig );
        
        /* Determine, whether c1 is an exterior outline or an interior one */
        d_start = 0;
        for( d=0; d<num_contours; d++ )
        {
            d_end = end_points[d];
            if ( d != c && d_end < MAX_GLYPH_POINTS )
            {
                size_t d_length = d_end - d_start + 1;
                size_t p = start;
                int c_inside_d = 1;
                while( p <= end )
                {
                    if ( !point_in_polygon( point_coords + 2*d_start, d_length, point_coords + 2*p ) ) {
                        c_inside_d = 0;
                        break;
                    }
                    p++;
                }
                c1.is_hole ^= c_inside_d;
            }
            d_start = cast( typeof( d_start ) ) ( d_end + 1 );
        }
        
        start = cast( typeof( start ) ) ( end + 1 );
    }
    
    tri_indices = cast( typeof( tri_indices ) )malloc( MAX_GLYPH_TRI_INDICES * PointIndex.sizeof );
    if ( !tri_indices )
        return TrError.TR_ALLOC_FAIL;
    
    /*
    Determine, which triangles represent curves, and whether they are convex or concave curves.
    Write indices of the triangles
    Set convex and texture coordinate bits
    */
    for( c=0; c<num_contours; c++ )
    {
        LLNodeID node, next, prev;
        LLNodeID dummy, root;
        PointFlag vertex_id_bit = 2;
        
        if ( con[c].points.length < 3 )
            continue;
        
        root = con[c].points.root;
        if ( ( dummy = add_node( &con[c].points, root ) ) != LL_BAD_INDEX )
        {
            /* 2 on-curve points on both sides of an off-curve point might sometimes get the same ID bit.
            Then the on-curve points would have the same texture coordinates and the curve would render incorrectly
            This can be solved by duplicating the last point */
            point_flags[dummy] = point_flags[root];
            point_coords[ 2 * dummy ] = point_coords[ 2 * root ];
            point_coords[ 2 * dummy + 1 ] = point_coords[ 2 * root + 1 ];
            
            if ( dummy+1 > gt.num_points_total )
                gt.num_points_total = cast(typeof(gt.num_points_total)) ( dummy+1 );
        }
        
        node = root;
        do {
            next = LL_NEXT( con[c].points, node );
            
            /* Get the highest node index in use */
            if ( node+1 > gt.num_points_total )
                gt.num_points_total = cast(typeof(gt.num_points_total)) ( node+1 );
            
            if ( !( point_flags[ node ] & PT_ON_CURVE ) )
            {
                /* Off-curve point */
                int    is_clockwise;
                int    is_convex;
                size_t t;
                
                prev = LL_PREV( con[c].points, node );
                is_clockwise = ac_cross_ab( point_coords + 2 * prev, point_coords + 2 * node, point_coords + 2 * next ) > 0;
                is_convex = ( is_clockwise == con[c].clockwise ) ^ con[c].is_hole;
                t = 3 * num_tris_curve;
                
                if ( t < MAX_GLYPH_TRI_INDICES - 3 )
                {
                    /* add a triangle */
                    
                    tri_indices[ t + is_convex ] = next;
                    tri_indices[ t + !is_convex ] = prev;
                    tri_indices[ t + 2 ] = node;
                    
                    /* point_flags[ node ] = 0; should already be zero */
                    point_flags[ prev ] = vertex_id_bit | PT_ON_CURVE;
                    point_flags[ next ] = ( vertex_id_bit = vertex_id_bit ^ 2 ) | PT_ON_CURVE;
                    point_flags[ node ] = is_convex << 2; /* the provoking vertex gets the convex bit (GL default is last) */
                    
                    num_tris_curve += 1;
                }
            }
            
            node = next;
        } while( node != root );
    }
    
    /* Triangulate */
    if ( 1 )
    {
        MyGLUCallbackArg arg;
        
        arg.coords = point_coords;
        arg.flags = point_flags;
        arg.newpts = &new_points_list;
        arg.num = num_tris_curve * 3;
        arg.ptr = tri_indices;
        arg.num_points_total = &gt.num_points_total;
        
        gluTessBeginPolygon( trgu.tess, &arg );
        
        for( c=0; c<num_contours; c++ )
        {
            LLNodeID node, next;
            
            if ( con[c].points.length < 3 )
                continue;
            
            gluTessBeginContour( trgu.tess );
            node = con[c].points.root;
            do {
                int must_add = 1;
                
                next = LL_NEXT( con[c].points, node );
                
                if ( !( point_flags[ node ] & PT_ON_CURVE ) )
                {
                    /* Must not add those off-curve points that are outside the interior polygon */
                    must_add ^= ( point_flags[ node ] >> 2 );
                }
                
                if ( must_add )
                {
                    int[ (void*).sizeof == size_t.sizeof ] test;
                    cast(void) test;
                    
                    trgu.glu_coords[node][0] = point_coords[ 2*node ];
                    trgu.glu_coords[node][1] = point_coords[ 2*node+1 ];
                    /* glu_coords[node][2] = 0;
                    Using the X coordinate of the next vertex as a Z coordinate seems to work just fine
                    (even though it might be garbage) */
                    
                    gluTessVertex( trgu.tess, trgu.glu_coords[node].ptr, cast(void*)cast(size_t) node );
                }
                
                node = next;
            } while( node != con[c].points.root );
            
            gluTessEndContour( trgu.tess );
        }
        
        gluTessEndPolygon( trgu.tess );
        num_tris_solid = arg.num / 3 - num_tris_curve;
        /** gt.num_points_total += new_points_list.length; **/
    }
    
    gt.num_indices_curve = cast(ushort) ( 3 * num_tris_curve );
    gt.num_indices_solid = cast(ushort) ( 3 * num_tris_solid );
    gt.num_indices_total = cast(ushort) ( gt.num_indices_curve + gt.num_indices_solid );
    
    if ( gt.num_indices_total > 0 )
    {
        gt.indices = cast(typeof(gt.indices)) realloc( tri_indices, PointIndex.sizeof * gt.num_indices_total );
        
        if ( !gt.indices )
        {
            free( tri_indices );
            return TrError.TR_ALLOC_FAIL;
        }
    }
    else
    {
        /* didn't need indices at all */
        gt.indices = null;
        free( tri_indices );
    }
    
    return TrError.TR_SUCCESS;
}
