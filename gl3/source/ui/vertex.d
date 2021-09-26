module ui.vertex;

version ( GL3 ):
import deps.gl3;


struct Vertex5
{
    GLfloat x, y;
    GLfloat r, g, b;
}

// Linear Vertex
// Text Vertex
// Image Vertex
struct LinearVertex
{
    GLshort x, y;       // 4byte
    GLubyte[4] color;   // 4byte
}
struct TextVertex
{
    GLfloat x, y;
    GLfloat r, g, b, a;
}
struct ImageVertex
{
    GLfloat x, y;
    GLfloat r, g, b, a;
    GLfloat tx, ty;
}
