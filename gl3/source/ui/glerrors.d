module ui.glerrors;

version ( GL3 ):
import deps.gl3;
import core.stdc.stdio  : printf;
import core.stdc.stdlib : exit;


nothrow @nogc
void checkGlError( const(char)* op ) 
{
    for ( GLint error = glGetError(); error; error = glGetError() ) 
    {
        printf( "error: GL: after %s(): glError (0x%x): %s\n", op, error, glGetErrorString( error ) );
//        version ( D_BetterC ) {} else
//            assert( 0 );
    }
}

nothrow @nogc
const(char*) glGetErrorString( GLenum error )
{
    switch ( error )
    {
    case GL_NO_ERROR:          return "No Error";
    case GL_INVALID_ENUM:      return "Invalid Enum";
    case GL_INVALID_VALUE:     return "Invalid Value";
    case GL_INVALID_OPERATION: return "Invalid Operation";
    case GL_INVALID_FRAMEBUFFER_OPERATION: return "Invalid Framebuffer Operation";
    case GL_OUT_OF_MEMORY:     return "Out of Memory";
    //case GL_STACK_UNDERFLOW:   return "Stack Underflow";
    //case GL_STACK_OVERFLOW:    return "Stack Overflow";
    //case GL_CONTEXT_LOST:      return "Context Lost";
    default:                   return "Unknown Error";
    }
}
