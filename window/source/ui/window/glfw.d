module ui.window.glfw;

version( GLFW ):
import deps.glfw;
import core.stdc.stdio;
import std.stdio : writeln;
//import ui.event : Event;


/** */
struct Window
{
    GLFWwindow* glfwWindow;
    alias glfwWindow this;

    @disable this();


    this( int w, int h, string name )
    {
        debug writeln( __FUNCTION__ );      
        glfwWindowHint( GLFW_CONTEXT_VERSION_MAJOR, 3 );
        glfwWindowHint( GLFW_CONTEXT_VERSION_MINOR, 3 );

        glfwWindow = glfwCreateWindow( w, h, name.ptr, null, null );
        if ( ! glfwWindow ) 
        {
            return;
        }

        glfwMakeContextCurrent( glfwWindow );
        glfwSwapInterval( 1 ); // Set vsync on so glfwSwapBuffers will wait for monitor updates.
                               // note: 1 is not a boolean! Set e.g. to 2 to run at half the monitor refresh rate.
   }

    ~this()
    {
        debug writeln( __FUNCTION__ );      
        if ( glfwWindow )
            glfwDestroyWindow( glfwWindow );
    }


    //int on( Event* event )
    //{
    //    return 0;
    //}
}
