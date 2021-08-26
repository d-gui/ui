module ui.shaders.shader;

version( GL3 ):
import deps.gl3;
import core.stdc.stdlib : malloc;
import core.stdc.stdlib : free;
import core.stdc.stdio  : printf;
import core.stdc.stdio  : fprintf;
import core.stdc.stdio  : stderr;
import std.traits;
import std.meta;


struct Shader( string vertexShaderSource, string geometryShaderSource, string fragmentShaderSource )
{
    GLuint program;
    alias program this;

    nothrow @nogc
    load()
    {
        static if ( vertexShaderSource.length )
        {
            GLuint vertexShader   = _createShader( GL_VERTEX_SHADER, vertexShaderSource );
            alias vertexShaderAlias = AliasSeq!(vertexShader);
        }
        else
        {
            alias vertexShaderAlias = AliasSeq!();
        }

        static if ( geometryShaderSource.length )
        {
            GLuint geometryShader = _createShader( GL_GEOMETRY_SHADER, geometryShaderSource );
            alias geometryShaderAlias = AliasSeq!(geometryShader);
        }
        else
        {
            alias geometryShaderAlias = AliasSeq!();
        }

        static if ( fragmentShaderSource.length )
        {
            GLuint fragmentShader = _createShader( GL_FRAGMENT_SHADER, fragmentShaderSource );
            alias fragmentShaderAlias = AliasSeq!(fragmentShader);
        }
        else
        {
            alias fragmentShaderAlias = AliasSeq!();
        }

        //
        alias validArgs = AliasSeq!( vertexShaderAlias, geometryShaderAlias, fragmentShaderAlias );
        program = _createProgram( validArgs );

        //
        static if ( fragmentShaderSource.length )
            glDeleteShader( fragmentShader );

        static if ( geometryShaderSource.length )
            glDeleteShader( geometryShader );

        static if ( vertexShaderSource.length )
            glDeleteShader( vertexShader );
    }

    nothrow @nogc
    ~this()
    {
        glDeleteProgram( program );
    }
}


nothrow @nogc
GLuint _createShader( GLenum type, string source )
{
    const GLint shader = glCreateShader( type );
    const GLint[1] lengths = [cast( int ) source.length];
    const(char)*[1] sources = [source.ptr];
    glShaderSource( shader, 1, sources.ptr, lengths.ptr );
    glCompileShader( shader );

    GLint status;
    glGetShaderiv( shader, GL_COMPILE_STATUS, &status );

    if ( status == GL_FALSE )
    {
        GLint infoLogLength;
        glGetShaderiv( shader, GL_INFO_LOG_LENGTH, &infoLogLength );

        auto mem = malloc( infoLogLength + 1 );
        GLchar* strInfoLog = cast( GLchar* ) mem;
        glGetShaderInfoLog( shader, infoLogLength, null, strInfoLog );

        string strShaderType;
        switch( type )
        {
            case GL_VERTEX_SHADER:   strShaderType = "vertex";   break;
            case GL_GEOMETRY_SHADER: strShaderType = "geometry"; break;
            case GL_FRAGMENT_SHADER: strShaderType = "fragment"; break;
            default:
                strShaderType = "unknown"; break;
        }
        
        fprintf( stderr, "error: Compile failure in %s shader:\n%s\n", strShaderType.ptr, strInfoLog );

        free( mem );
    }

    return shader;
}


nothrow @nogc
GLuint _createProgram( ARGS... )( ARGS shaderList )
{
    GLuint program = glCreateProgram();
    
    static
    foreach( shader; shaderList )
    {
        glAttachShader( program, shader );
    }
    
    glLinkProgram( program );
    
    GLint status;
    glGetProgramiv( program, GL_LINK_STATUS, &status );

    if ( status == GL_FALSE )
    {
        GLint infoLogLength;
        glGetProgramiv( program, GL_INFO_LOG_LENGTH, &infoLogLength );
        
        auto mem = malloc( infoLogLength + 1 );
        GLchar* strInfoLog = cast( GLchar* ) mem;
        glGetProgramInfoLog( program, infoLogLength, null, strInfoLog );

        fprintf( stderr, "error: Linker failure: %s\n", strInfoLog );

        free( mem );
    }
    
    static
    foreach( shader; shaderList )
    {
        glDetachShader( program, shader );
        glAttachShader( program, shader );
    }

    return program;
}
