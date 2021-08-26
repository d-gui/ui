#version 330 core
layout (location = 0) in vec2 aPosition;
layout (location = 1) in vec4 aColor;
layout (location = 2) in vec2 aTexCoord;
out vec4 fragColor;
out vec2 fragTexCoord;

void main()
{
    gl_Position  = vec4( aPosition, 0.0, 1.0 );
    fragColor    = aColor;
    fragTexCoord = aTexCoord;
}
