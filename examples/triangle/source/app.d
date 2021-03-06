import deps.glfw;
import deps.gl3;
import core.stdc.stdio  : printf;
import ui.app           : App;
import ui.triangle      : drawTriangle;
import ui.glerrors      : checkGlError;


int main( string[] args ) 
{
	return App!drawFrame( args );
}


void drawFrame( T )( ref T window )
{
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

	int width, height;
	glfwGetFramebufferSize( window, &width, &height );
	glViewport( 0, 0, width, height );

	//
	drawTriangle( 100, 300, 700, 300, 400, 0, 0xFFFFFFFF );
}
