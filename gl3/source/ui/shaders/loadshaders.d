module ui.shaders.loadshaders;

version( GL3 ):
import ui.shaders;


nothrow @nogc
void loadShaders()
{
    loadLinearShader();
    loadImageShader();
    loadTextShader();
}
