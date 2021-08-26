module ui.app;

import deps.glfw; // glfw...
import deps.gl3;  // defaultInitGL, gl...
import core.stdc.stdio  : printf;
import core.stdc.stdlib : exit;
import std.stdio        : writeln;
import ui.window        : Window;
import ui.glerrors      : checkGlError;
import ui.shaders       : loadShaders;


template App( alias DrawFrameFunc )
{
    alias App = App!( defaultInitFunc, DrawFrameFunc );

}

template App( alias InitFunc, alias DrawFrameFunc )
{
    struct App
    {
        int _result;
        alias _result this;

        Window window;
        @disable this();


        this( ref string[] args )
        {
            debug writeln( __FUNCTION__ );

            window = Window( 800, 600, "OpenGL" );

            InitFunc( this );

            defaultEventLoop();
        }

        ~this()
        {
            debug writeln( __FUNCTION__ );      
        }


        /** */
        void defaultEventLoop()
        {
            debug writeln( __FUNCTION__ );

            while ( !glfwWindowShouldClose( window ) )
            {
                DrawFrameFunc( window );
                glfwSwapBuffers( window );
                glfwPollEvents();
            }
        }
    }
}

void defaultInitFunc( T )( ref T app )
{
    debug writeln( __FUNCTION__ );

    deps.gl3.loadOpenGL();

    loadShaders();
}

