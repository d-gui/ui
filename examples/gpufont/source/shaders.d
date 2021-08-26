module shaders;

import core.stdc.stdio;
import deps.gl3;


enum MAX_BINDS = 32;
static GLchar[MAX_BINDS][64] bind_names;
static GLuint[MAX_BINDS] bind_numbers;
static size_t num_binds = 0;

/* Scans the shader code for the following pattern:
    //%bindattr NAME NUMBER
This is a workaround to shitty drivers that don't support the 'layout' qualifier
*/
static 
void scan_attr_bindings( const GLchar[] code, size_t code_len )
{
    int[ char.sizeof == GLchar.sizeof ] size_check;
    const GLchar[] key = "//%bindattr ";
    const size_t k_end = key.sizeof / key[0].sizeof - 2;
    size_t n, k = 0;
    
    num_binds = 0;
    cast(void) size_check;
    
    for( n=0; n<code_len; n++ )
    {
        if ( code[n] == '\0' )
            break;
        else if ( code[n] == key[k] && ++k == k_end )
        {
            uint index = 0;
            if ( sscanf( code.ptr+n, " %64s %u", bind_names[num_binds].ptr, &index ) == 2 )
            {
                k = 0;
                bind_numbers[num_binds] = index;
                if ( ++num_binds == MAX_BINDS )
                    break;
            }
        }
    }
}

static void bind_attributes( GLuint prog )
{
    size_t n;
    for( n=0; n<num_binds; n++ ) {
        printf( "Vertex attribute: %s -> %u\n", bind_names[n].ptr, bind_numbers[n] );
        glBindAttribLocation( prog, bind_numbers[n], bind_names[n].ptr );
    }
}

static
GLuint compile_shader_code( const GLchar[] code, size_t code_len, GLenum shader_type )
{
    GLuint s;
    GLint ok, slen = cast( int ) code_len;
    
    scan_attr_bindings( code, code_len );
    
    s = glCreateShader( shader_type );
    auto codePtr = code.ptr;
    glShaderSource( s, 1, &codePtr, &slen );
    glCompileShader( s );
    glGetShaderiv( s, GL_COMPILE_STATUS, &ok );
    
    if ( ok == GL_FALSE )
    {
        GLchar[4096] buf;
        GLsizei info_len = 0;
        glGetShaderInfoLog( s, buf.sizeof / buf[0].sizeof - 1, &info_len, buf.ptr );
        glDeleteShader( s );
        buf[ info_len ] = s = 0;
        printf( "Failed to compile. Info log:\n%s\n", buf.ptr );
    }
    
    return s;
}

static
GLuint load_shader_file( const char *filename, GLenum shader_type )
{
    GLchar[1<<15] buf; /* 32 KiB */
    size_t len;
    FILE *fp;
    
    printf( "Loading shader '%s'\n", filename );
    
    fp = fopen( filename, "r" );
    if ( !fp ) {
        printf( "Failed to open file\n" );
        return 0;
    }
    
    len = fread( buf.ptr, buf[0].sizeof, buf.sizeof / buf[0].sizeof, fp );
    fclose( fp );
    
    return compile_shader_code( buf, len, shader_type );
}

GLuint load_shader_prog( const char *vs_filename, const char *fs_filename )
{
    GLuint p, vs, fs;
    
    p = glCreateProgram();
    
    vs = load_shader_file( vs_filename, GL_VERTEX_SHADER );
    bind_attributes( p );
    
    fs = load_shader_file( fs_filename, GL_FRAGMENT_SHADER );
    bind_attributes( p );
    
    if ( vs && fs )
    {
        GLint ok;
        
        glAttachShader( p, vs );
        glAttachShader( p, fs );
        glLinkProgram( p );
        
        ok = GL_FALSE;
        glGetProgramiv( p, GL_LINK_STATUS, &ok );
        
        if ( p == GL_FALSE ) {
            GLchar[4096] info;
            GLsizei len = 0;
            glGetProgramInfoLog( p, info.sizeof / info[0].sizeof - 1, &len, info.ptr );
            glDeleteProgram( p );
            info[len] = p = 0;
            printf( "Failed to link. Info log:\n%s\n", info.ptr );
        } else {
            glUseProgram( p );
        }
    }
    else
    {
        glDeleteProgram( p );
        p = 0;
    }
    
    /*
    If 'p' was created and linked succesfully:
        shaders will be deleted as soon as 'p' is deleted (i.e. at exit)
    otherwise:
        shaders get deleted immediately (or very quickly anyway)
    */
    if ( vs ) glDeleteShader( vs );
    if ( fs ) glDeleteShader( fs );
    
    return p;
}

GLint locate_uniform( GLuint prog, const char *name )
{
    GLint u = glGetUniformLocation( prog, name );
    if ( u == -1 ) printf( "Warning: uniform '%s' not found\n", name );
    return u;
}

