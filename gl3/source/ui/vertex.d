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
    GLfloat x, y;
    GLfloat r, g, b, a;
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
