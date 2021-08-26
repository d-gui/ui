import deps.glfw;
import deps.gl3;
import core.stdc.stdio  : printf;
import std.stdio        : writeln;
import ui.window        : Window;


void main() 
{
	debug writeln( __FUNCTION__ );


	auto window = Window( 800, 600, "OpenGL" );

	deps.gl3.loadOpenGL(); // from deps.gl3


	void draw()
	{
	 //   glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

		//int width, height;
		//glfwGetFramebufferSize( window, &width, &height );
		//glViewport( 0, 0, width, height );
	}


	void mainLoop()
	{
		debug writeln( __FUNCTION__ );

		while ( !glfwWindowShouldClose( window ) ) 
		{
			draw();
			glfwSwapBuffers( window );
			glfwPollEvents();
		}
	}

	mainLoop();
}
