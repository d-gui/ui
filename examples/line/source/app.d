import deps.glfw;
import deps.gl3;
import core.stdc.stdio  : printf;
import ui.app           : App;
import ui.line          : drawLine;
import ui.glerrors      : checkGlError;
import std.stdio : writeln;


int main( string[] args ) 
{
	return App!drawFrame( args );
}


void drawFrame( T )( ref T window )
{
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

	int width, height;
	glfwGetFramebufferSize( window, &width, &height );
	//glViewport( 0, 0, width, height );
	GLint[2] data;
	glGetIntegerv( GL_MAX_VIEWPORT_DIMS, data.ptr );
	//writeln( "GL_MAX_VIEWPORT_DIMS: ", data[0], " ", data[1] );
	//glViewport( 0, 0, data[0], data[1] ); checkGlError( "glViewport" );
	//glViewport( 0, 0, 800, 600 ); checkGlError( "glViewport" );

	//
	drawLine( 100, 300, 700, 300, 0xFF000000 );
	//drawLine( 0, 0, 799, 599, 0xFF000000 );
}
