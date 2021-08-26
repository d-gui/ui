#version 330

layout(location = 0) in vec2 aPosition;
layout(location = 1) in vec4 aColor;
out vec4 fragColor;

void main() {
    gl_Position = vec4( aPosition, 0.0, 1.00 );
    fragColor = aColor;
}
