import deps.glfw;
import deps.gl3;
import core.stdc.stdio  : printf;
import core.stdc.stdlib : exit;
import std.stdio        : writeln;
import std.stdio        : writefln;
import ui.app           : App;
import ui.line          : drawLine;
import ui.glerrors      : checkGlError;
import derelict.opengl.glu;

import shaders;
import gpufont_draw;
import gpufont_data;
import gpufont_ttf_file;


//string the_font_filename = "/usr/share/fonts/truetype/droid/DroidSans.ttf";
//string the_font_filename = "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf";
string the_font_filename = "data/DroidSans.ttf";
string text     = "data/artofwar.txt";
Font the_font;


int main( string[] args ) 
{
	return App!( customInit, drawFrame )( args );
}


void customInit( T )( T app )
{
	int status;

    //
    GLuint font_prog;
	font_prog = load_shader_prog( "data/bezv.glsl", "data/bezf.glsl" );    
	if ( !font_prog )
		exit( -1 );

	if ( !init_font_shader( font_prog ) )
		exit( -1 );

	printf( "Font: '%s'\n", the_font_filename.ptr );
	//millis = SDL_GetTicks();
	status = load_ttf_file( &the_font, the_font_filename.ptr );
	
	if ( status )
	{
		writeln( "Failed to load the font: ", status );
		//printf( "Failed to load the font (%d)\n", status );
		exit( -1 );
	}
}


void drawFrame( T )( ref T window)
{
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

	int width, height;
	glfwGetFramebufferSize( window, &width, &height );
	glViewport( 0, 0, width, height );

	//
	drawLine( 100, 300, 700, 300, 0xFFFFFFFF);
}


// 
// Glyph
//   Vertices -> GPU
//
// GPU
//   vertex shader
//
//   geometry shader
//     in vertices
//     emit scan_line
//
//   fragment shader
//     color

