module ui.triangle;

version ( GL3 ):
import deps.gl3;
import ui.shaders  : linearShader;
import ui.vertex   : LinearVertex;
import ui.glerrors : checkGlError;


void drawTriangle( T )( T x, T y, T x2, T y2, T x3, T y3, uint rgba )
  if ( is( T == int ) || is( T == uint ) || is( T == long ) || is( T == ulong ) )
{
    drawTriangle( x, y, x2, y2, x3, y3,
        ( rgba >> 24 ) & 0xFF,
        ( rgba >> 16 ) & 0xFF,
        ( rgba >>  8 ) & 0xFF,
        ( rgba       ) & 0xFF 
    );
}

void drawTriangle( T )( T x, T y, T x2, T y2, T x3, T y3, ubyte r, ubyte g, ubyte b, ubyte a )
  if ( is( T == int ) || is( T == uint ) || is( T == long ) || is( T == ulong ) )
{
    int viewportWidth  = 800;
    int viewportHeight = 600;
    float windowedViewportCenterX = cast( GLfloat ) viewportWidth  / 2;
    float windowedViewportCenterY = cast( GLfloat ) viewportHeight / 2;

    //
    pragma( inline, true )
    auto deviceX( T windowedX )
    {
        return ( cast( GLfloat ) windowedX - windowedViewportCenterX ) / viewportWidth * 2;
    }

    pragma( inline, true )
    auto deviceY( T windowedY )
    {
        return -( cast( GLfloat ) windowedY - windowedViewportCenterY ) / viewportHeight * 2;
    }

    //
    GLfloat GL_x = deviceX( x );
    GLfloat GL_y = deviceY( y );

    GLfloat GL_x2 = deviceX( x2 );
    GLfloat GL_y2 = deviceY( y2 );

    GLfloat GL_x3 = deviceX( x3 );
    GLfloat GL_y3 = deviceY( y3 );

    //printf( "x,  y  : %d, %d\n", x,  y );
    //printf( "x2, y2 : %d, %d\n", x2, y2 );
    //printf( "x,  y  : %f, %f\n", GL_x,  GL_y );
    //printf( "x2, y2 : %f, %f\n", GL_x2, GL_y2 );

    //
    alias TVertex = LinearVertex;
    TVertex[3] vertices =
    [
        TVertex( GL_x,  GL_y,  cast( GLfloat ) r/255, cast( GLfloat ) g/255, cast( GLfloat ) b/255, cast( GLfloat ) a/255 ), // start
        TVertex( GL_x2, GL_y2, cast( GLfloat ) r/255, cast( GLfloat ) g/255, cast( GLfloat ) b/255, cast( GLfloat ) a/255 ), // end
        TVertex( GL_x3, GL_y3, cast( GLfloat ) r/255, cast( GLfloat ) g/255, cast( GLfloat ) b/255, cast( GLfloat ) a/255 ), // end
    ];

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
    glBufferData( GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr, /*usage hint*/ GL_STATIC_DRAW ); checkGlError( "glBufferData" );

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
    glDrawArrays( GL_TRIANGLES, /*first*/ 0, /*count*/ cast( int ) vertices.length ); checkGlError( "glDrawArrays" );

    // Free
    glBindBuffer( GL_ARRAY_BUFFER, 0 );
    glDisableVertexAttribArray(1);
    glDisableVertexAttribArray(0);
    glBindVertexArray( 0 );
    glUseProgram( 0 );
    glDeleteBuffers( 1, &vbo );
    glDeleteVertexArrays( 1, &vao );
}
