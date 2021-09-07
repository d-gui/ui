module ui.lines;

version ( GL3 ):
import deps.gl3;
import ui.shaders  : linearShader;
import ui.vertex   : LinearVertex;
import ui.glerrors : checkGlError;
import std.math    : round;
import std.stdio : writeln;

alias INDEX = size_t;
alias COORD = int;
alias COLOR = uint;


struct Vec2i
{
    COORD x;
    COORD y;

    Vec2i opBinary( string op : "+" )( Vec2i b )
    {
        return 
            Vec2i(
                x + b.x,
                y + b.y
            );
    }

    Vec2i opBinary( string op : "-" )( Vec2i b )
    {
        return 
            Vec2i(
                x - b.x,
                y - b.y
            );
    }
}

alias Point = Vec2i;


struct Line
{
    Point a;
    Point b;

    auto x( COORD y )
    {
        // x = k*y + shift; 
        // k = ( x - shift ) / y;
        // shift = x - k*y; 
        // shift = x; // y = 0
        auto nb = b - a;

        auto shiftb = a.x;

        auto kb = ( cast( float ) nb.x / nb.y );
        auto x = cast( COORD ) round( kb * (y - a.y) + shiftb );

        return x;
    }

    // bezie quadratic curve
    auto quadraticX( COORD y )
    {
        auto x = y;
        return x;
    }
}


struct XXLine
{
    COORD  x1; 
    COORD  x2; 
    COORD  y; 
    size_t nextIndex; // index in buffer

    pragma( inline, true )
    auto a()
    {
        return Point( x1, y );
    }

    pragma( inline, true )
    auto b()
    {
        return Point( x2, y );
    }

    //auto toVertex( TVertex )( COLOR color )
    //{
    //    return TVertex( x1, y, x2, y, color );
    //}
}


struct XXLines
{
    XXLine[] lines;
    alias lines this;
}




void drawLines( Line[] lines, uint rgba )
{
    drawLines( lines, 
        ( rgba >> 24 ) & 0xFF,
        ( rgba >> 16 ) & 0xFF,
        ( rgba >>  8 ) & 0xFF,
        ( rgba       ) & 0xFF 
    );
}

void drawLines( XXLines lines, uint rgba )
{
    drawLines( lines, 
        ( rgba >> 24 ) & 0xFF,
        ( rgba >> 16 ) & 0xFF,
        ( rgba >>  8 ) & 0xFF,
        ( rgba       ) & 0xFF 
    );
}

//void drawLines( T )( T lines, ubyte r, ubyte g, ubyte b, ubyte a )
//  if ( is( T == Line[] ) || is ( T == XXLines ) )
void drawLines( T )( T lines, ubyte r, ubyte g, ubyte b, ubyte a )
  if ( is( T == Line[] ) || is ( T == XXLines ) )
{
    int viewportWidth  = 800;
    int viewportHeight = 600;
    float windowedViewportCenterX = cast( GLfloat ) viewportWidth  / 2;
    float windowedViewportCenterY = cast( GLfloat ) viewportHeight / 2;

    //
    pragma( inline, true )
    auto deviceX( int windowedX )
    {
        return ( cast( GLfloat ) windowedX - windowedViewportCenterX ) / viewportWidth * 2;
    }

    pragma( inline, true )
    auto deviceY( int windowedY )
    {
        return -( cast( GLfloat ) windowedY - windowedViewportCenterY ) / viewportHeight * 2;
    }

    //
    alias TVertex = LinearVertex;
    TVertex[] vertices;
    vertices.reserve( lines.length * 2 );

    foreach ( line; lines )
    {
        static if ( is ( T == Line[] ) )
        {
            vertices ~= 
                TVertex(
                    deviceX( line.a.x ),
                    deviceY( line.a.y ),
                    cast( GLfloat ) r/255, 
                    cast( GLfloat ) g/255, 
                    cast( GLfloat ) b/255, 
                    cast( GLfloat ) a/255
                );

            vertices ~= 
                TVertex(
                    deviceX( line.b.x ),
                    deviceY( line.b.y ),
                    cast( GLfloat ) r/255, 
                    cast( GLfloat ) g/255, 
                    cast( GLfloat ) b/255, 
                    cast( GLfloat ) a/255
                );
        }

        // Optimized for multiple lines
        else // if ( is ( T == XXLines ) )
        {
            vertices ~= 
                TVertex(
                    deviceX( line.x1 ),
                    deviceY( line.y ),
                    cast( GLfloat ) r/255, 
                    cast( GLfloat ) g/255, 
                    cast( GLfloat ) b/255, 
                    cast( GLfloat ) a/255
                );

            vertices ~= 
                TVertex(
                    deviceX( line.x2 ),
                    deviceY( line.y ),
                    cast( GLfloat ) r/255, 
                    cast( GLfloat ) g/255, 
                    cast( GLfloat ) b/255, 
                    cast( GLfloat ) a/255
                );
        }
    }

    // Init code
    //auto vao = VAO( vertices );
    GLuint vbo;
    GLuint vao;

    // Vertex Array
    glGenVertexArrays( 1, &vao ); checkGlError( "glGenVertexArrays" );
    glBindVertexArray( vao ); checkGlError( "glBindVertexArray" );

    // Buffers
    glGenBuffers( 1, &vbo ); checkGlError( "glGenBuffers" );
    glBindBuffer( GL_ARRAY_BUFFER, vbo ); checkGlError( "glBindBuffer" );

    // Upload data to GPU
    glBufferData( 
        GL_ARRAY_BUFFER, 
        TVertex.sizeof * vertices.length, 
        vertices.ptr, 
        /*usage hint*/ GL_STATIC_DRAW 
    ); checkGlError( "glBufferData" );

    // Projection
    // mat3 projection_2D{ { sx, 0.f, 0.f },{ 0.f, sy, 0.f },{ tx, ty, 1.f } }; // affine transformation as introduced in the prev. lecture
    // GLint projection_uloc = glGetUniformLocation( texmesh.effect.program, "projection" );
    // glUniformMatrix3fv( projection_uloc, 1, GL_FALSE, cast(float*) &projection );

    // Describe array
    int aPosition = glGetAttribLocation( linearShader, "aPosition" );
    glEnableVertexAttribArray( aPosition ); checkGlError( "glEnableVertexAttribArray" );
    glVertexAttribPointer(
        /*location*/ aPosition, 
        /*num elements*/ 2, 
        /*base type*/ GL_FLOAT, 
        /*normalized*/ GL_FALSE,
        TVertex.sizeof, 
        cast( void* ) TVertex.x.offsetof
    ); checkGlError( "glVertexAttribPointer 1" );

    int aColor = glGetAttribLocation( linearShader, "aColor" );
    glEnableVertexAttribArray( aColor ); checkGlError( "glEnableVertexAttribArray" );
    glVertexAttribPointer(
        /*location*/ aColor, 
        /*num elements*/ 4, 
        /*base type*/ GL_FLOAT, 
        /*normalized*/ GL_FALSE,
        TVertex.sizeof, 
        cast( void* ) TVertex.r.offsetof
    ); checkGlError( "glVertexAttribPointer 2" );

    // Drawing code (in render loop)
    // Style
    glUseProgram( linearShader ); checkGlError( "glUseProgram" );

    // VAO
    glBindVertexArray( vao ); checkGlError( "glBindVertexArray" );

    // Draw
    glDrawArrays( GL_LINES, /*first*/ 0, /*count*/ cast( int ) vertices.length ); checkGlError( "glDrawArrays" );

    // Free
    glBindBuffer( GL_ARRAY_BUFFER, 0 );
    glDisableVertexAttribArray(1);
    glDisableVertexAttribArray(0);
    glBindVertexArray( 0 );
    glUseProgram( 0 );
    glDeleteBuffers( 1, &vbo );
    glDeleteVertexArrays( 1, &vao );

    //
    // shader.use();
    // shader.color = color;
    // shader.array = vertices;
    //
    // draw
    //
}
