module ui.shaders.linear;

version( GL3 ):
import deps.gl3;
import ui.shaders.shader : Shader;


enum vertexShaderSource   = import( "linear-vert.glsl" );
enum fragmentShaderSource = import( "linear-frag.glsl" );

alias LinearShader = Shader!( vertexShaderSource, "", fragmentShaderSource );
LinearShader linearShader;

 
nothrow @nogc
void loadLinearShader()
{
    linearShader.load();
}

