module ui.shaders.text;

version( GL3 ):
import deps.gl3;
import ui.shaders.shader : Shader;


enum vertexTextShaderSrc   = import( "text-vert.glsl" );
enum fragmentTextShaderSrc = import( "text-frag.glsl" );

alias TextShader = Shader!( vertexTextShaderSrc, "", fragmentTextShaderSrc );
TextShader textShader;
 
nothrow @nogc
void loadTextShader()
{
    textShader.load();
}
