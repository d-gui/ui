module ui.shaders.image;

version( GL3 ):
import deps.gl3;
import ui.shaders.shader : Shader;


enum vertexImageShaderSrc   = import( "image-vert.glsl" );
enum fragmentImageShaderSrc = import( "image-frag.glsl" );

alias ImageShader = Shader!( vertexImageShaderSrc, "", fragmentImageShaderSrc );
ImageShader imageShader;

 
nothrow @nogc
void loadImageShader()
{
    imageShader.load();
}
