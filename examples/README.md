# Examples

## window
```D
    import ui.window;

    auto window = createMainWindow( 800, 600, "OpenGL" );
```
![window-glfw.png](_demo/window-glfw.png)

## line
```D
    import ui.line;

    drawLine( 100, 300, 700, 300, 1.0f, 1.0f, 1.0f );
```
![line-gl3.png](_demo/line-gl3.png)

## triangle
```D
    import ui.triangle;

    drawTriangle( 100, 300, 700, 300, 400, 0, 0.3f, 0.3f, 0.3f );
```
![triangle-gl3.png](_demo/triangle-gl3.png)

## fonts
```D
    import ui.fonts;

    auto fontFilePath = 
        queryFont( 
            /* family  */ "arial".toStringz,
            /* style   */ 0, 
            /* height  */ 16, 
            /* slant   */ 0, 
            /* outline */ 0.0f
        );

    printf( "fontFilePath: %s\n", fontFilePath );

    free( fontFilePath );
```
![fonts-list.png](_demo/fonts-list.png)

