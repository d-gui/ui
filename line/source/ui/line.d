module ui.line;

version ( GL3 ):
import deps.gl3;
import ui.shaders  : linearShader;
import ui.vertex   : LinearVertex;
import ui.glerrors : checkGlError;


void drawLine( int x, int y, int x2, int y2, uint rgba )
{
    drawLine( x, y, x2, y2, 
        ( rgba >> 24 ) & 0xFF,
        ( rgba >> 16 ) & 0xFF,
        ( rgba >>  8 ) & 0xFF,
        ( rgba       ) & 0xFF 
    );
}

struct Viewport
{
    uint x;
    uint y;
    uint w;
    uint h;
}

void drawLine( int x, int y, int x2, int y2, ubyte r, ubyte g, ubyte b, ubyte a )
{
    Viewport viewport;
    viewport.w = 800;
    viewport.h = 600;

    drawLine( viewport, x, y, x2, y2, r, g, b, a );
}

void drawLine( Viewport viewport, int x, int y, int x2, int y2, ubyte r, ubyte g, ubyte b, ubyte a )
{
    float windowedViewportCenterX = cast( GLfloat ) viewport.w  / 2;
    float windowedViewportCenterY = cast( GLfloat ) viewport.h / 2;

    //
    pragma( inline, true )
    auto deviceX( int windowedX )
    {
        return ( cast( GLfloat ) windowedX - windowedViewportCenterX ) / viewport.w * 2;
    }

    pragma( inline, true )
    auto deviceY( int windowedY )
    {
        return -( cast( GLfloat ) windowedY - windowedViewportCenterY ) / viewport.h * 2;
    }

    //
    GLfloat GL_x = deviceX( x );
    GLfloat GL_y = deviceY( y );

    GLfloat GL_x2 = deviceX( x2 );
    GLfloat GL_y2 = deviceY( y2 );

    //printf( "x,  y  : %d, %d\n", x,  y );
    //printf( "x2, y2 : %d, %d\n", x2, y2 );
    //printf( "x,  y  : %f, %f\n", GL_x,  GL_y );
    //printf( "x2, y2 : %f, %f\n", GL_x2, GL_y2 );

    //
    alias TVertex = LinearVertex;
    TVertex[2] vertices =
    [
        TVertex( GL_x,  GL_y,  cast( GLfloat ) r/255, cast( GLfloat ) g/255, cast( GLfloat ) b/255, cast( GLfloat ) a/255 ), // start
        TVertex( GL_x2, GL_y2, cast( GLfloat ) r/255, cast( GLfloat ) g/255, cast( GLfloat ) b/255, cast( GLfloat ) a/255 ), // end
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
