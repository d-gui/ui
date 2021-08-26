import std;

import std;
import deps.freetype;
import ui.fonts;
import core.stdc.stdlib : exit;
import deps.glfw;
import deps.gl3;
import core.stdc.stdio : printf;
import ui.window       : createMainWindow;
import ui.window       : MainWindow;
import ui.line         : drawLine;
import ui.triangle     : drawTriangle;
import ui.glerrors     : checkGlError;

// pixel_size = point_size * resolution / 72
enum _DPI = 72;
enum SIZE_PT = 144;
enum SIZE_PX = SIZE_PT * _DPI / 72;

MainWindow win;
Pathes pathes;


void drawChar( int code, string family, int size )
{
    pathes.length = 0;
    linearize( code, family, size, &pathes ); // load glyph, convert to lines
    triangulate( &pathes, &triangles );
    printf( "Total triangles : %ld\n", triangles.length / 3 );
}

void main() 
{
    //drawChar( 79, "arial", SIZE_PX );
    drawChar( 79, "Arial", SIZE_PX );

    win = createMainWindow( 800, 600, "OpenGL" );
    initGL();
    mainLoop();
}


void initGL()
{
    // Back color
    //glClearColor( .4, .4, .4, 1 ); checkGlError( "glClearColor" );

    // Texture blending
    //glDisable( GL_DEPTH_TEST ); checkGlError( "glDisable" );
    //glEnable( GL_BLEND ); checkGlError( "glEnable" );
    //glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA ); checkGlError( "glBlendFunc" );

    // Anti-aliasing
    glfwWindowHint( GLFW_SAMPLES, 4 );
    glEnable( GL_MULTISAMPLE );
    glEnable( GL_LINE_SMOOTH );
    glLineWidth( 0.5f );
    glEnable( GL_BLEND );
    glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
    glDisable( GL_DEPTH_TEST ); checkGlError( "glDisable" );
    glHint( GL_LINE_SMOOTH_HINT, GL_NICEST );

    // Shaders
    import ui.shaders;
    loadShaders();
}


void draw()
{
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

    int width, height;
    glfwGetFramebufferSize( win, &width, &height );
    glViewport( 0, 0, width, height );

    //
    //drawTriangles( &triangles );
    drawLines( &pathes );
}


/** */
void mainLoop()
{
    while ( !glfwWindowShouldClose( win ) ) 
    {
        draw();
        glfwSwapBuffers( win );
        glfwPollEvents();
    }
}


void linearize( int charCode, string family, int size, Pathes* pathes )
{
    import std.math;

    // Get Font File
    auto fontRec = 
        queryFont( 
            /* family  */ family.toStringz,
            /* style   */ 0, 
            /* height  */ size, 
            /* slant   */ 0, 
            /* outline */ 0.0f
        );

    if ( fontRec )
    {
        printf( "fontRec.fileName: %s\n", fontRec.fileName );
    }
    else
    {
        printf( "fontRec.fileName: null\n" );
        exit( -1 );
    }

    // Get Glyph
    FT_Face face;
    auto err = 
        FT_New_Face( 
            ft,
            fontRec.fileName,
            fontRec.faceIndex,
            &face
        );

    if ( err != FT_Err_Ok )
    {
        auto errStr = FT_Error_String( err );
        printf( "error: FreeType: FT_New_Face(): (%x) %s\n", err, errStr );
    }

    printf( "num_glyphs      : %ld\n", face.num_glyphs );
    printf( "units_per_EM    : %d\n", face.units_per_EM );

    auto dpi = getDPI();

    err = 
        FT_Set_Char_Size(
            face,       /* handle to face object           */
            0,          /* char_width in 1/64th of points  */
            cast( FT_F26Dot6 ) ( SIZE_PT * 64 - 32 ),       /* char_height in 1/64th of points */
            _DPI,      /* horizontal device resolution    */
            _DPI       /* vertical device resolution      */
        );    
    //err =
    //    FT_Set_Pixel_Sizes( 
    //        face,
    //        0,
    //        SIZE_PX
    //    );

    if ( err != FT_Err_Ok )
    {
        auto errStr = FT_Error_String( err );
        printf( "error: FreeType: FT_Set_Char_Size(): (%x) %s\n", err, errStr );
    }

    //
    printf( "metrics:\n" );
    printf( "  x_ppem  : %d\n",  face.size.metrics.x_ppem );
    printf( "  y_ppem  : %d\n",  face.size.metrics.y_ppem );
    printf( "  x_scale : %ld\n", face.size.metrics.x_scale );
    printf( "  y_scale : %ld\n", face.size.metrics.y_scale );

    err = 
        FT_Load_Char(
            face,
            charCode,
            FT_LOAD_NO_BITMAP
            //FT_LOAD_NO_HINTING
            //FT_LOAD_FORCE_AUTOHINT
            //FT_LOAD_TARGET_LCD
        );
    if ( err != FT_Err_Ok )
    {
        auto errStr = FT_Error_String( err );
        printf( "error: FreeType: FT_Load_Char(): (%x) %s\n", err, errStr );
    }

    // Get Outline
    FT_Glyph oneGlyph;
    err = FT_Get_Glyph( face.glyph, &oneGlyph );

    FT_OutlineGlyph outlineGlyph;
    if ( oneGlyph.format == FT_GLYPH_FORMAT_OUTLINE )
    {
        outlineGlyph = cast( FT_OutlineGlyph ) oneGlyph;
    }
    else
    {
        printf( "error: glyph not outline\n" );
        return;
    }

    //
    auto outline = outlineGlyph.outline;

    // 
    printf( "n_contours  : %d\n", outline.n_contours );
    printf( "n_points    : %d\n", outline.n_points );

    // Bounds
    FT_BBox bbox;
    err = 
        FT_Outline_Get_BBox( 
            &outline,
            &bbox
        );
    printf( "xmin, ymin, xmax, ymax: %ld, %ld, %ld, %ld\n", bbox.xMin, bbox.yMin, bbox.xMax, bbox.yMax );

    // Flip up-down
    FT_Matrix matrix;
    const FT_Fixed multiplier = 0x1_00_00L;
    matrix.xx =  1L * multiplier;
    matrix.xy =  0L * multiplier;
    matrix.yx =  0L * multiplier;
    matrix.yy = -1L * multiplier;

    FT_Outline_Transform(
        &outline,
        &matrix 
    );

    // Move
    FT_Outline_Translate( 
        &outline,
        0,
        bbox.yMax + 1 * 64
    );

    //
    // Convert Bezie to Lines
    //

    // Split outline to contours
    //   for each
    //     Get orientation 
    //     Decompose
    //     Store into path

    //  Set callbacks
    FT_Outline_Funcs func_interface;
    func_interface.move_to  = &_moveTo;
    func_interface.line_to  = &_lineTo;
    func_interface.conic_to = &_conicTo;
    func_interface.cubic_to = &_cubicTo;
    func_interface.shift    = 0;
    func_interface.delta    = 0;

    // Get primary outline orientation
    pathes.orientation = FT_Outline_Get_Orientation( &outline );

    //
    foreach ( ref outl; FT_Outline_Iterator( outline ) )
    {
        Path path;
        err = FT_Outline_Decompose( &outl, &func_interface, &path );
        path.orientation = FT_Outline_Get_Orientation( &outl );

        *pathes ~= path;
    }

    // Free
    freeFontRecord( fontRec );
}


FT_Vector[] triangles;

struct Pathes
{
    Path[] _pathes;
    alias _pathes this;

    FT_Orientation orientation;
}


void drawLines( Pathes* pathes )
{
    foreach ( ref path; *pathes )
    {
        FT_Vector a = path.points[0];

        foreach ( b; path.points )
        {
            drawLine( 
                cast( int )a.x, cast( int )a.y, 
                cast( int )b.x, cast( int )b.y, 
                0x00FF00FF
            );

            drawLine( 
                cast( int )a.x -5, 
                cast( int )a.y, 
                cast( int )a.x +5, 
                cast( int )a.y, 
                0xFF0000FF
            );

            drawLine( 
                cast( int )a.x, 
                cast( int )a.y -5, 
                cast( int )a.x , 
                cast( int )a.y +5, 
                0xFF0000FF
            );

            a.x = b.x;
            a.y = b.y;
        }
    }
}

void drawTriangles( FT_Vector[]* triangles )
{
    import std.range;

    foreach ( tri; (*triangles).chunks( 3 ) )
    {
        auto a = tri[0];
        auto b = tri[1];
        auto c = tri[2];

        drawTriangle( 
            a.x, a.y, 
            b.x, b.y, 
            c.x, c.y, 
            //0.0f, 0.5f, 0.0f 
            0xFFFFFFFF
        );
    }    
}


struct FT_Vector_Overloaded
{
    FT_Vector _vector;
    alias _vector this;

    //nothrow
    //this( int x, int y )
    //{
    //    _vector.x = x;
    //    _vector.y = y;
    //}

    nothrow
    this( FT_Pos x, FT_Pos y )
    {
        _vector.x = x;
        _vector.y = y;
    }

    nothrow @nogc
    const double opIndex( size_t i )
    {
        if ( i == 0 )
            return cast( const double ) _vector.x;
        else
            return cast( const double ) _vector.y;
    }

    nothrow @nogc
    void opAssign( FT_Vector b )
    {
        x = b.x;
        y = b.y;
    }

    nothrow @nogc
    void opAssign( FT_Vector_Overloaded* b )
    {
        x = b.x;
        y = b.y;
    }
}

import earcutd;
import dvector;

nothrow
void triangulate( Pathes* pathes, FT_Vector[]* triangles )
{
    Path[] polygon;

    triangles.length = 0;

    void tri( ref Path[] polygon, FT_Vector[]* triangles )
    {
        //Earcut!(size_t, Dvector!(Dvector!(FT_Vector_Overloaded))) earcut;
        Earcut!( size_t, Path[], FT_Vector ) earcut;
        earcut.run( polygon );

        // Save triangles
        Path totalPoints;
        foreach ( ref pat; polygon )
        {
            totalPoints ~= pat.points;
        }
        
        // Convert Index to Coord
        for ( auto i=0; i < earcut.indices.length; i++ )
        {
            *triangles ~= totalPoints[ earcut.indices[ i ]  ];
        }

        // indices must be freed.
        earcut.indices.free;
    }

    foreach ( ref path; *pathes )
    {
        // main contour
        if ( path.orientation == pathes.orientation )
        {
            // Triangulate prev package
            if ( polygon.length > 0 )
            {
                tri( polygon, triangles );
                polygon.length = 0;
            }

            // Create new Polygon
            polygon ~= path;
        }

        // hole
        else
        {
            // Add hole
            polygon ~= path;
        }
    }

    if ( polygon.length > 0 )
    {
        tri( polygon, triangles );
        polygon.length = 0;
    }
}


//
alias Bool = byte;
enum Bool SUCCESS = 0;
enum Bool FAILURE = 1;


extern (C) nothrow
int _moveTo( const(FT_Vector)* to, void* user )
{
    import std.math;

    printf( "moveTo: %ld, %ld\n", to.x, to.y );
    auto path = cast( Path * ) user;

    path.points ~= scale( to );

    return SUCCESS;
}

extern (C) nothrow
int _lineTo( const(FT_Vector)* to, void* user )
{
    import std.math;

    printf( "lineTo: %ld, %ld\n", to.x, to.y );
    auto path = cast( Path * ) user;

    path.points ~= scale( to );

    return SUCCESS;
}

nothrow
FT_Vector scale( const(FT_Vector*) vec )
{
    return 
        FT_Vector( 
            vec.x / 64, 
            vec.y / 64
        );
}

extern (C) nothrow
int _conicTo( const(FT_Vector)* control, const(FT_Vector)* to, void* user )
{
    import std.math;
    import std.range;

    printf( "conicTo: %ld, %ld\n", to.x, to.y );
    auto path = cast( Path* ) user;

    auto  a = path.points.back;
    auto  contr = scale( control );
    auto  b = scale( to );
    float t = 0.5f;

    //rasSplitConic( path, &a, &contr, &b );
    
    path.points ~= b;

    return SUCCESS;
}


auto length( FT_Vector a )
{
    import std.math;
    return sqrt( cast( double )a.x*a.x + a.y*a.y );
}



nothrow
void rasSplitConic( Path* path, const(FT_Vector*) a, const(FT_Vector*) control, const(FT_Vector*) b, float t = 0.5f, float dt = 0.25f )
{
    import std.range;
    import std.math;

    // Center
    auto mid = splitConic( a, control, b, t );

    //
    if ( ! pointInLine2( &mid, a, b ) )
    {
            if ( dt > 0.00001f )
            {
                // left
                //printf( "  try left\n" );
                if ( t - dt > 0.0f )
                    rasSplitConic( path, a, control, b, t - dt, dt/2 );

                if ( path.points.back.x != mid.x && path.points.back.y != mid.y )
                {
                    printf( "  mid: %ld, %ld\n", mid.x, mid.y );
                    path.points ~= mid;
                }

                // right
                //printf( "  try right\n" );
                if ( t + dt < 1.0f )
                    rasSplitConic( path, a, control, b, t + dt, dt/2 );
            }
    }

/+
    // Plain line
    auto res = pointInLine( &mid, a, b );

    switch ( res )
    {
        case PointInLineResult.between:
        case PointInLineResult.originDestination:
            // FINISH
            break;
        case PointInLineResult.origin:
            // TO RIGHT
            if ( t - dt > 0.0f )
                rasSplitConic( path, a, control, b, t - dt, dt/2 );

            if ( path.points.back != mid )
            {
                path.points ~= cast( FT_Vector_Overloaded )mid;
                printf( "  mid 1: %ld, %ld\n", mid.x, mid.y );
            }
            break;
        case PointInLineResult.destination:
            // TO LEFT
            if ( path.points.back != mid )
            {
                path.points ~= cast( FT_Vector_Overloaded )mid;
                printf( "  mid 2: %ld, %ld\n", mid.x, mid.y );
            }

            // right
            //printf( "  try right\n" );
            if ( t + dt < 1.0f )
                rasSplitConic( path, a, control, b, t + dt, dt/2 );
            break;
        case PointInLineResult.left:
        case PointInLineResult.right:
        case PointInLineResult.none:
            if ( dt > 0.1f )
            {
                // left
                //printf( "  try left\n" );
                if ( t - dt > 0.0f )
                    rasSplitConic( path, a, control, b, t - dt, dt/2 );

                if ( path.points.back != mid )
                {
                    path.points ~= cast( FT_Vector_Overloaded )mid;
                    printf( "  mid: %ld, %ld\n", mid.x, mid.y );
                }

                // right
                //printf( "  try right\n" );
                if ( t + dt < 1.0f )
                    rasSplitConic( path, a, control, b, t + dt, dt/2 );
            }
            break;
        default:
    }
+/
}


//auto flatness( const(FT_Vector*) pointA, controlPointA, const(FT_Vector*) pointB )
//{
//    import std.math : pow;

//    auto ux = pow( 3 * controlPointA.x - 2 * pointA.x - pointB.x, 2 );
//    auto uy = pow( 3 * controlPointA.y - 2 * pointA.y - pointB.y, 2 );
//    auto vx = pow( 3 * controlPointB.x - 2 * pointB.x - pointA.x, 2 );
//    auto vy = pow( 3 * controlPointB.y - 2 * pointB.y - pointA.y, 2 );
 
//    if( ux < vx )
//        ux = vx;
 
//    if( uy < vy )
//        uy = vy;
 
//    return ux + uy;
//}

enum PointInLineResult
{
    none,
    between,
    origin,
    destination,
    originDestination,
    left,
    right,
}


nothrow
PointInLineResult pointInLine( const(FT_Vector*) p2, const(FT_Vector*) p0, const(FT_Vector*) p1 )
{
    import std.math : abs;

    FT_Vector a;
    FT_Vector b;

    a.x = p1.x - p0.x;
    a.y = p1.y - p0.y;

    b.x = p2.x - p0.x;
    b.y = p2.y - p0.y;

    long sa = a.x * b.y - b.x * a.y;

    if ((a.x * b.x < 0.0) || (a.y * b.y < 0.0))
        return PointInLineResult.left;
    if (a.length() < b.length())
        return PointInLineResult.right;
    if ( p0 == p2 && p1 == p2 )
        return PointInLineResult.originDestination;
    if ( p0 == p2 )
        return PointInLineResult.origin;
    if ( p1 == p2 )
        return PointInLineResult.destination;
    if ( sa == 0 )
        return PointInLineResult.between;
    else
        return PointInLineResult.none;
}

pragma( inline, true )
nothrow
bool pointInLine2( const(FT_Vector*) p_test, const(FT_Vector*) p0, const(FT_Vector*) p1 )
{
    import std.math : abs;

    FT_Vector a;
    FT_Vector b;
    FT_Vector p;

    // tested point
    a.x = p0.x;
    a.y = p0.y;

    // to center p0
    b.x = p1.x - p0.x;
    b.y = p1.y - p0.y;

    p.x = p_test.x - p0.x;
    p.y = p_test.y - p0.y;

    // y = k * x;
    //auto k = cast( float ) b.y / b.x;

    //
    //if ( p.y == round( cast( float ) p.x * k ) )
    //printf( "p.y * b.x == p.x * b.y: %ld, %ld\n", p.y * b.x, p.x * b.y );
    if ( p.y * b.x == p.x * b.y )
        return true;
    else
        return false;
}

nothrow
FT_Vector splitConic( const(FT_Vector*) startPt, const(FT_Vector*) controlPt, const(FT_Vector*) endPt, float t )
{
    import std.math;

    auto x = cast( FT_Pos ) round( pow( 1.0f-t, 2 ) * startPt.x + 2 * (1.0f-t) * t * controlPt.x + pow( t, 2 ) * endPt.x ); 
    auto y = cast( FT_Pos ) round( pow( 1.0f-t, 2 ) * startPt.y + 2 * (1.0f-t) * t * controlPt.y + pow( t, 2 ) * endPt.y ); 

    return FT_Vector( x, y );
}


extern (C) nothrow
int _cubicTo( const(FT_Vector)* control1, const(FT_Vector)* control2, const(FT_Vector)* to, void* user )
{
    printf( "cubicTo: %ld, %ld\n", to.x, to.y );
    auto path = cast( Path* ) user;

    path.points ~= scale( to );

    return SUCCESS;
}



struct Path
{
    FT_Vector[] points;
    alias points this;

    FT_Orientation orientation;
    FT_Long x_scale;// x_scale = face->size->metrics.x_scale / 65536.0;;
    FT_Long y_scale;// y_scale = face->size->metrics.y_scale / 65536.0;;
}


struct FT_Outline_Iterator
{
    FT_Outline _outline;
    alias _outline this;

    pragma( inline, true )
    int opApply( scope int delegate( ref FT_Outline outline ) dg )
    {
        int        result      = 0;
        auto       contoursPtr = contours;
        ushort     a           = 0;
        ushort     b;
        FT_Outline outl;

        for ( auto i = n_contours; i != 0; i--, contoursPtr++, a = b )
        {
            b = *contoursPtr; // contour end point index
            b++;              // contour end point index + 1

            *contoursPtr -= a;

            outl.n_contours = 1;
            outl.n_points   = cast( short )( b - a );
            outl.points     = points + a;
            outl.tags       = tags + a;
            outl.contours   = contoursPtr; // contours end points
            outl.flags      = flags;

            result = dg( outl );

            if ( result )
                return result;
        }

        return 0;
    }
}

// Font Family, Font Size, Char
//   triangles
/*
struct CharCache
{
    alias TCode = int;
    alias THash = int;
    Triangles[ TCode ][ THash ] _storage;

    int hash( string family, int size )
    {
        return 0;
    }

    Triangles* get( string family, int size, int code )
    {
        auto _hash = hash( family, size );
        auto c1 = _hash in _storage;
        if ( c1 !is null )
        {
            auto c2 = code in c1;
            if ( c1 !is null )
            {
                return *c2;
            }
            else
            {
                return null;
            }
        }
        else
        {
            return null;
        }
    }
}

*/

DPI getDPI()
{
    import std.math;  

    DPI dpi;

    GLFWmonitor* monitor = glfwGetPrimaryMonitor();

    int width_mm, height_mm;
    glfwGetMonitorPhysicalSize( monitor, &width_mm, &height_mm );

    const GLFWvidmode* mode = glfwGetVideoMode(monitor);

    dpi.x = cast( int ) round( mode.width / width_mm * 25.4 );
    dpi.y = cast( int ) round( mode.height / height_mm * 25.4 );

    writeln( "mode.width : ", mode.width );
    writeln( "width_mm   : ", width_mm );
    writeln( "dpi        : ", dpi );

    return dpi;
}


struct DPI
{
    int x;
    int y;
}


