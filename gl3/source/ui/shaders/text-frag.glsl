#version 330 core
in  vec4 fragColor;
in  vec2 fragTexCoord;
out vec4 theColor;

uniform sampler2D fragTexture;

void main()
{
    //theColor = texture( fragTexture, TexCoord ) * ourColor;  
    theColor = texture( fragTexture, fragTexCoord ) * fragColor;
}
