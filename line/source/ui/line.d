module ui.line;

version ( GL3 ):
import deps.gl3;
import ui.shaders  : linearShader;
import ui.vertex   : LinearVertex;
import ui.glerrors : checkGlError;
import std.stdio : writeln;


struct Viewport
{
    uint x;
    uint y;
    uint w;
    uint h;
}

pragma( inline, true )
auto deviceX( int windowed_x, int viewport_w )
{
    const int short_size = short.max - short.min;
    return 
        cast( GLshort ) ( cast( int ) short_size * windowed_x / viewport_w - short_size/2 );
}

pragma( inline, true )
auto deviceY( int windowed_y, int viewport_h )
{
    const int short_size = short.max - short.min;
    return 
        cast( GLshort ) -( cast( int ) short_size * windowed_y / viewport_h - short_size/2 );
}


void drawLine( int x, int y, int x2, int y2, uint abgr )
{
    Viewport viewport;
    viewport.w = 800;
    viewport.h = 600;

    //
    GLshort GL_x = deviceX( x, viewport.w );
    GLshort GL_y = deviceY( y, viewport.h );

    GLshort GL_x2 = deviceX( x2, viewport.w );
    GLshort GL_y2 = deviceY( y2, viewport.h );

    struct Color
    {
        union
        {
            uint abgr;
            struct
            {
                ubyte a, b, g, r;
            }
            ubyte[4] bytes;
        }
    }

    auto c = Color(abgr);

    //
    alias TVertex = LinearVertex;
    TVertex[2] vertices =
    [
        TVertex( GL_x,  GL_y,  [c.r, c.g, c.b, c.a] ), // start
        TVertex( GL_x2, GL_y2, [0xff, 0xff, 0xff, 0xff] ), // end
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
    auto aPosition = glGetAttribLocation( linearShader, "aPosition" ); checkGlError( "glGetAttribLocation" );
    glEnableVertexAttribArray( aPosition ); checkGlError( "glEnableVertexAttribArray 1" );
    glVertexAttribPointer(
        /*location*/     aPosition, 
        /*num elements*/ 2, 
        /*base type*/    GL_SHORT,
        /*normalized*/   GL_TRUE,
        /*stride*/       TVertex.sizeof, 
        cast( void* ) TVertex.x.offsetof
    ); checkGlError( "glVertexAttribPointer 1" );

    auto aColor = glGetAttribLocation( linearShader, "aColor" ); checkGlError( "glGetAttribLocation" );
    glEnableVertexAttribArray( aColor ); checkGlError( "glEnableVertexAttribArray 2" );
    glVertexAttribPointer(
        /*location*/     aColor, 
        /*num elements*/ 4, 
        /*base type*/    GL_UNSIGNED_BYTE, 
        /*normalized*/   GL_TRUE,
        /*stride*/       TVertex.sizeof, 
        cast( void* ) TVertex.color.offsetof
    ); checkGlError( "glVertexAttribPointer 2" );

    // Drawing code (in render loop)
    // Style
    glUseProgram( linearShader ); checkGlError( "glUseProgram" );

    // VAO
    glBindVertexArray( vao ); checkGlError( "glBindVertexArray" );

    // Draw
    glDrawArrays( 
        GL_LINES, 
        /*first*/ 0, 
        /*count*/ cast( int ) vertices.length 
    ); checkGlError( "glDrawArrays" );

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
