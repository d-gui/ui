module ui.oswindow;

version( window ):
version( GDI ):
import core.sys.windows.windows;
import ui;

pragma( lib, "user32.lib" );
pragma( lib, "gdi32.lib" ); 


//
enum DWORD STYLE_BASIC               = ( WS_CLIPSIBLINGS | WS_CLIPCHILDREN );
enum DWORD STYLE_FULLSCREEN          = ( WS_POPUP );
enum DWORD STYLE_BORDERLESS          = ( WS_POPUP );
enum DWORD STYLE_BORDERLESS_WINDOWED = ( WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX );
enum DWORD STYLE_NORMAL              = ( WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX );
enum DWORD STYLE_RESIZABLE           = ( WS_THICKFRAME | WS_MAXIMIZEBOX );
enum DWORD STYLE_MASK                = ( STYLE_FULLSCREEN | STYLE_BORDERLESS | STYLE_NORMAL | STYLE_RESIZABLE );

enum WPARAM IDT_TIMER1 = WM_USER + 1;

/** */
class OSWindow : RenderContext
{
    Document* document;

    /** */
    this( int w, int h )
    {
        _w = w;
        _h = h;
        _createOSWindowClass();
        _createOSWindow();
    }


    /** */
    this( Document* document )
    {
        this.document = document;
        _w = 640;
        _h = 480;
        _createOSWindowClass();
        _createOSWindow();
    }


    /** */
    void center( Point praCenter, int x, int y )
    {
        _center.x = praCenter.x + x;
        _center.y = praCenter.y - y;
    }


    /** */
    Point center()
    {
        return _center;
    }


    /** */
    Size size() nothrow
    {
        return Size( _w, _h );
    }


    /** */
    void clear() nothrow
    {
        RECT crect;
        crect.left   = 0;
        crect.top    = 0;
        crect.right  = _w;
        crect.bottom = _h;

        // Color
        HBRUSH brush = CreateSolidBrush( RGB( 0x00, 0x00, 0x0 ) );

        // Rect
        FillRect( _hdc, &crect, brush );

        DeleteObject( brush );
    }


    void color( Color color )
    {
        pen( color );
    }

    
    void pen( Color color )
    {
        HPEN hpen = CreatePen( PS_SOLID, _pen_w, color.windowsCOLORREF );
        auto praPen = SelectObject( _hdc, hpen );
        DeleteObject( praPen );
    }


    void pen( Color color, int w )
    {
        _pen_w = w;
        HPEN hpen = CreatePen( PS_SOLID, w, color.windowsCOLORREF );
        auto praPen = SelectObject( _hdc, hpen );
        DeleteObject( praPen );
    }


    void pen( Color color, PenType penType, int w )
    {
        _pen_w = w;
        HPEN hpen = CreatePen( penType, w, color.windowsCOLORREF );
        auto praPen = SelectObject( _hdc, hpen );
        DeleteObject( praPen );
    }


    void pen( ref Pen pen )
    {
        _pen_w = pen.width;
        HPEN hpen = CreatePen( pen.type, pen.width, pen.color.windowsCOLORREF );
        auto praPen = SelectObject( _hdc, hpen );
        DeleteObject( praPen );
    }


    void moveTo( int x, int y )
    {
        Point p = center + Point( x, -y );
        MoveToEx( _hdc, p.x, p.y, NULL );
    }


    void point( POS x, POS y, Color color )
    {
        SetPixel( _hdc, x, y, color.windowsCOLORREF );
    }


    void lineTo( int x, int y )
    {
        Point p = center + Point( x, -y );
        LineTo( _hdc, p.x, p.y );
    }


    void rectangle( int w, int h )
    {
        // Center ot the Vid
        Point cen = this.center;

        version ( Polyline )
        {
            // top left
            Point point = cen - Point( w / 2, h / 2 );

            SetPolyFillMode( _hdc, WINDING );
            auto brush = CreateSolidBrush( GetDCPenColor( _hdc ) );
            auto oldBrush = SelectObject( _hdc, brush ); 

            // rectangle cd x gh
            Point[5] points;
            points[0] = point + Point(  0,  0 );  // start
            points[1] = point + Point(  w,  0 );  // to right
            points[2] = point + Point(  w,  h );  // to bottom
            points[3] = point + Point(  0,  h );  // to left
            points[4] = point + Point(  0,  0 );  // to top
            Polyline( _hdc, cast( POINT* ) points.ptr, 5 );
        }
        else
        {
            RECT rect = { cen.x - w/2, cen.y - h/2, cen.x + w/2, cen.y + h/2 };
            auto brush = CreateSolidBrush( GetDCPenColor( _hdc ) );
            FrameRect( _hdc, &rect, brush );
            DeleteObject( brush );
        }
    }


    void rectangle( int l, int t, int r, int b )
    {
        import std.math : abs;

        // Center ot the Vid
        Point cen = this.center;

        // rectangle cd x gh
        Point[5] points;
        points[0] = cen + Point( l, -t );  // start
        points[1] = cen + Point( r, -t );  // to right
        points[2] = cen + Point( r, -b );  // to bottom
        points[3] = cen + Point( l, -b );  // to left
        points[4] = cen + Point( l, -t );  // to top

        // 
        Polyline( _hdc, cast( POINT* ) points.ptr, 5 );
    }


    void rectangleFilled( int w, int h, Color color )
    {
        // Center ot the Vid
        Point cen = this.center;

        // top left
        Point point = cen - Point( w / 2, h / 2 );

        // rectangle cd x gh
        Point[5] points;
        points[0] = point + Point(  0,  0 );  // start
        points[1] = point + Point(  w,  0 );  // to right
        points[2] = point + Point(  w,  h );  // to bottom
        points[3] = point + Point(  0,  h );  // to left
        points[4] = point + Point(  0,  0 );  // to top

        // Fill Mode
        SetPolyFillMode( _hdc, WINDING );
        auto brush = CreateSolidBrush( color.windowsCOLORREF );
        auto oldBrush = SelectObject( _hdc, brush ); 

        // 
        Polygon( _hdc, cast( POINT* ) points.ptr, 5 );

        // 
        SelectObject( _hdc, oldBrush ); 
        DeleteObject( brush);
    }


    void rectangleFilled( int l, int t, int r, int b, Color color )
    {
        import std.math : abs;

        // Center ot the Vid
        Point cen = this.center;

        // rectangle cd x gh
        Point[5] points;
        points[0] = cen + Point( l, -t );  // start
        points[1] = cen + Point( r, -t );  // to right
        points[2] = cen + Point( r, -b );  // to bottom
        points[3] = cen + Point( l, -b );  // to left
        points[4] = cen + Point( l, -t );  // to top

        // Fill Mode
        SetPolyFillMode( _hdc, WINDING );
        auto brush = CreateSolidBrush( color.windowsCOLORREF );
        auto oldBrush = SelectObject( _hdc, brush ); 

        // 
        //Polyline( _hdc, points.ptr, 5 );
        Polygon( _hdc, cast( POINT* ) points.ptr, 5 );

        // 
        SelectObject( _hdc, oldBrush ); 
        DeleteObject( brush);
    }


    void font( string name, uint size )
    {
        //
    }


    void symbol( wchar wc, int l, int t, int r, int b )
    {
        //
    }


    void text( string s, int w, int h, ref TextSet textSet )
    {
        _text_nowrap( s, w, h, textSet );
    }


    void _text_nowrap( string s, int w, int h, ref TextSet textSet )
    {
        //import std.encoding : codePoints;
        //import std.range    : lockstep;
        //import ui.text      : LineSet;

        //textSet.cdghs.length = s.length;

        //int cur_c = 0;
        //int cur_d = 0;
        //int cur_g = 0;
        //int cur_h = 0;
        //int next_d = 0;
        //int next_g = 0;

        //int text_c = 0;
        //int text_d = 0;
        //int text_g = 0;
        //int text_h = 0;
        //size_t charsCount = 0;

        //string line;
        //int line_c = 0;
        //int line_d = 0;
        //int line_g = 0;
        //int line_h = 0;
        //size_t lineStart = 0;

        //Size charcdgh;
        //auto rectPtr = textSet.cdghs.ptr;

        //foreach ( i, c; s.codePoints )
        //{
        //    // char cd, gh
        //    _fontCharCDGH( cast( wchar ) c, charcdgh );

        //    next_d = cur_c + charcdgh.cd;
        //    next_g = cur_h - charcdgh.gh;

        //    // limit
        //    // wrap
        //    if ( next_d > cd )
        //    {
        //        // trim char rects
        //        textSet.cdghs.length = charsCount;
        //        // line
        //        line = s[ lineStart .. i ];
        //        line_d = cur_d;
        //        line_g = cur_g;
        //        textSet.lines ~= LineSet( line, line_c, line_d, line_g, line_h );
        //        // text
        //        text_d = max( text_d, line_d );
        //        text_g = line_g;
        //        textSet.c  = text_c;
        //        textSet.d  = text_d;
        //        textSet.cd = text_d - text_c;
        //        textSet.g  = text_g;
        //        textSet.h  = text_h;
        //        textSet.gh = text_h - text_g;
        //        break;
        //    }

        //    //
        //    cur_g = cur_h - charcdgh.gh;
        //    cur_d = cur_c - charcdgh.cd;

        //    // save char c, d, g, h
        //    rectPtr.c = cur_c;
        //    rectPtr.d = cur_d;
        //    rectPtr.g = cur_g;
        //    rectPtr.h = cur_h;

        //    // update cursor
        //    cur_c = cur_d;
        //    cur_h = cur_g;

        //    charsCount += 1;
        //    rectPtr += 1;
        //}
    }


    void _text_wrap_char( string s, int w, int h, ref TextSet textSet )
    {
        //
    }


    //ref int w()
    //{
    //    return _w;
    //}


    //ref int h()
    //{
    //    return _h;
    //}


    void _fontCharCDGH( wchar wc, ref Size size )
    {
        GetTextExtentPoint32( _hdc, cast( LPWSTR ) &wc, 1, &size.windowsSIZE );
    }


    //
    /** */
    void _createOSWindowClass()
    {   
        import std.file : thisExePath;
        import std.path : baseName;

        static size_t windowNum;

        windowNum += 1;

        auto classname = 
            format!
                "%s-%d"
                ( baseName( thisExePath ),
                  windowNum 
                )
                .toLPWSTR;

        if ( GetClassInfo( GetModuleHandle( NULL ), classname, &wc ) )
        {
            // class exists
            if ( wc.lpfnWndProc != &WindowProc )
            {
                throw new Exception( "Error when window class creation: class exists: " ~ classname.to!string );
            }
        }
        else
        {
            wc.style         = CS_HREDRAW | CS_VREDRAW;
            wc.lpfnWndProc   = &WindowProc;
            wc.cbClsExtra    = 0;
            wc.cbWndExtra    = 0;
            wc.hInstance     = GetModuleHandle( NULL );
            wc.hIcon         = LoadIcon( NULL, IDI_APPLICATION );
            wc.hCursor       = LoadCursor( NULL, IDC_ARROW );
            wc.hbrBackground = NULL;
            wc.lpszMenuName  = NULL;
            wc.lpszClassName = classname;

            if ( !RegisterClass( &wc ) )
                throw new Exception( "Error when window class creation" );
        }
    }


    /** */
    HWND _createOSWindow()
    {
        // Bordered Rectamgle
        RECT wrect = { 100, 100, 100 + _w, 100 + _h };
        AdjustWindowRectEx( &wrect, style, false, styleEx );

        //
        hwnd = 
            CreateWindowEx( 
                styleEx, 
                wc.lpszClassName,         // window class name
                "windowName".toLPWSTR,    // window caption
                style,                    //  0x00000008
                wrect.left,               // initial x position
                wrect.top,                // initial y position
                wrect.right - wrect.left, // initial x size
                wrect.bottom - wrect.top, // initial y size
                NULL,                     // parent window handle
                NULL,                     // window menu handle
                GetModuleHandle( NULL ),  // program instance handle
                cast ( void* ) this
            );

        _rememberWindow( hwnd, this );

        // Show
        ShowWindow( hwnd, SW_NORMAL );
        UpdateWindow( hwnd );

        return hwnd;
    }


    void clipRect( int cx, int cy, int w, int h )
    {
        int topLeftX;
        int topLeftY;
        topLeftX = _center.x + cx - w/2;
        topLeftY = _center.y + cy - h/2;
        BeginPath( _hdc );
        MoveToEx( _hdc, topLeftX,     topLeftY,     NULL );  // top left
        MoveToEx( _hdc, topLeftX + w, topLeftY,     NULL );  // top right
        MoveToEx( _hdc, topLeftX + w, topLeftY + h, NULL );  // bottom right
        MoveToEx( _hdc, topLeftX,     topLeftY + h, NULL );  // bottom left
        MoveToEx( _hdc, topLeftX,     topLeftY,     NULL );  // top left. finish
        EndPath( _hdc );
        SelectClipPath( _hdc, RGN_AND );
    }


    void set()
    {
        //
    }


    void vid()
    {
        if ( document !is null )
        {
            document.body.vid( this );
        }
    }

    int on( Event* event ) nothrow
    {
        try {
            switch ( event.type )
            {
                case WM_KEYDOWN:
                {
                    if ( document !is null )
                    //if ( document.body.instanceClass.on !is null )
                    {
                        //document.body.instanceClass.on( &document.body, event );

                        auto element = findObjectAt( &document.body, Point( 0, 0 ) );
                        if ( element !is null )
                        {
                            // class on()
                            foreach ( cls; element.classes )
                            {
                                if ( cls.on !is null )
                                {
                                    cls.on( element, event );
                                }
                            }
                        }
                    }
                    return 0;
                }

                case WM_LBUTTONDOWN:
                {
                    if ( document !is null )
                    {
                        auto element = findObjectAt( &document.body, event.mouseKey.to );
                        if ( element !is null )
                        {
                            writeln( "WM_LBUTTONDOWN: ", *element );
                            // class on()
                            foreach ( cls; element.classes )
                            {
                                if ( cls.on !is null )
                                {
                                    cls.on( element, event );
                                }
                            }

                            // element on()
                            //if ( element.instanceClass.on !is null )
                            //{
                            //    element.instanceClass.on( element, event );
                            //}
                        }
                    }
                    return 0;
                }

                default: return 0;
            }
        } catch ( Throwable e ) { assert( 0, e.toString() ); }
    }


    /** */
    void _setTimer()
    {
        SetTimer( 
            hwnd,
            IDT_TIMER1,
            5,
            cast ( TIMERPROC ) NULL 
        );
    }


private:
    WNDCLASS wc;
    HWND     hwnd;
    HDC      _hdc;
    DWORD    style = STYLE_NORMAL | STYLE_RESIZABLE;
    DWORD    styleEx = 0;
    int      _w;
    int      _h;
    Point    _center;
    uint     _pen_w = 1;



    // BackBuefer
    BackBuffer createBackBuffer( Rect rect ) nothrow
    {
        //
        auto bb_hdc = CreateCompatibleDC( _hdc );
        backBufferBitmap = 
            CreateCompatibleBitmap( 
                _hdc, 
                rect.right  - rect.left, 
                rect.bottom - rect.top 
            );
        oldBackBufferBitmap = SelectObject( _hdc, backBufferBitmap );

        ////    +1
        //// -1  . +1
        ////    -1
        //SetGraphicsMode( _hdc, GM_ADVANCED );
        //_center.x = w / 2;
        //_center.y = h / 2;

        auto backBuffer = new BackBuffer( bb_hdc, rect, this );
        return backBuffer;
    }


    // Windows Created by UI
    static OSWindow[ HWND ] _windows;

    static
    void _rememberWindow( HWND hwnd, OSWindow window )
    {
        _windows[ hwnd ] = window;
    }

    static
    auto _recallWindow( HWND hwnd )
    {
        return hwnd in _windows;
    }


    static
    auto _forgetWindow( HWND hwnd )
    {
        _windows.remove( hwnd );
    }


    // Default Window Proc
    static extern ( Windows )
    LRESULT WindowProc( HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam ) nothrow
    {
        PAINTSTRUCT ps;
        OSWindow*   window;

        //
        //if ( message == WM_CREATE )
        //    window = cast( OSWindow* ) ( cast( CREATESTRUCT* ) lParam ).lpCreateParams;
        //else
            window = _recallWindow( hwnd );

        //
        if ( window )
        {
            switch ( message )
            {
                // window unaccessable
                //case WM_CREATE: {
                //    try {
                //        //writeln( "onCreated() 1: ", hwnd, ": ", window );
                //        //emit!"onCreated"( window );
                //    } catch ( Throwable e ) { assert( 0, e.toString() ); }
                //    return 0;
                //}
                    
                case WM_PAINT: 
                {
                    // create Back Buffer
                    // draw on Back Buffer
                    // copy Back Buffer to thw Window
                    //
                    // Back Buffer is RenderContext

                    version ( DebugCalls ) Writeln( __FUNCTION__, ": WM_PAINT" );
                    //
                    version ( TestRenderTime )
                    {            
                        import core.time;
                        MonoTime t;
                        auto testRenderStartTime = t.currTime;
                    }

                    window._hdc = BeginPaint( hwnd, &ps );


////find update area
//GetUpdateRect(hWnd, &rClientRect, 0);
//if (IsRectEmpty(&rClientRect))
//      GetClientRect(hWnd, &rClientRect);
//
//BitBlt(ps.hdc, rClientRect.left,  rClientRect.top,  rClientRect.right -  rClientRect.left,  rClientRect.bottom - rClientRect.top,
//  hdcScreen, rClientRect.left,  rClientRect.top, SRCCOPY);
    
                    version ( DoubleBuffer )
                    {
                        scope auto backBuffer = window.createBackBuffer( cast( Rect ) ps.rcPaint );

                        // Clear
                        backBuffer.clear();

                        // Drawing
                        try {
                            RenderContext ctx;
                            renderElementsInRect( &ctx, backBuffer.document, cast( Rect ) ps.rcPaint );
                        } catch ( Throwable e ) { assert( 0, e.toString() ); }


                        // Transfer the off-screen DC to the screen
                        window.copy( backBuffer, cast( Rect ) ps.rcPaint );
                    }
                    else
                    {
                        //    +1
                        // -1  . +1
                        //    -1
                        SetGraphicsMode( window._hdc, GM_ADVANCED );
                        try {
                            auto p = Point( window._w / 2, window._h / 2 );
                            window.center( p, 0, 0 );
                        } catch ( Throwable e ) { assert( 0, e.toString() ); }

                        // Drawing
                        window.clear();

                        try {
                            window.set();
                            window.vid();
                        } catch ( Throwable e ) { assert( 0, e.toString() ); }
                    }

                    //
                    EndPaint( hwnd, &ps );

                    //
                    version( TestRenderTime )
                    {            
                        Writeln( t.currTime - testRenderStartTime );
                    }

                    return 0;
                }
                    
                //case WM_SYSKEYDOWN: 
                //    goto case WM_KEYDOWN;

                case WM_KEYDOWN: 
                {
                    Event event = { type: WM_KEYDOWN, keyboard: { hwnd, message, wParam, lParam } };
                    window.on( &event );
                    RedrawWindow( hwnd, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW );
                    return 0;
                }
                    
                case WM_LBUTTONDOWN: 
                {
                    Event event = { type: WM_LBUTTONDOWN, mouseKey: { hwnd, message, wParam, lParam } };
                    event.mouseKey.drawer = *window;

                    // center
                    auto size = window.size();
                    event.mouseKey.to.x =    GET_X_LPARAM( lParam ) - size.w / 2;
                    event.mouseKey.to.y = -( GET_Y_LPARAM( lParam ) - size.h / 2 );
                    
                    //
                    window.on( &event );

                    // update window
                    RedrawWindow( hwnd, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW );
                    //InvalidateRect( hwnd, NULL, 0 );
                    //UpdateWindow( hwnd );

                    //auto curObject = root.objectAtPoint( event.point );
                    //if ( curObject !is null )
                    //{
                    //    window.callHierarhically!( "onLeftMouseDown" )( curObject, event );
                    //}
                    return 0;
                }
                    
                //case WM_RBUTTONDOWN : {
                //    try {
                //        MouseKeyEvent event = { hwnd, message, wParam, lParam };
                //        //auto curObject = window.objectAtPointVSB( event.point );
                //        auto curObject = window.objectAtPoint( event.point );
                //        if ( curObject !is null )
                //        {
                //            window.callHierarhically!( "onRightMouseDown" )( curObject, event );
                //        }
                //    } catch ( Throwable e ) { assert( 0, e.toString() ); }
                //    return 0;
                //}
                    
                //case WM_LBUTTONUP : {
                //    try {
                //        MouseKeyEvent event = { hwnd, message, wParam, lParam };
                //        //auto curObject = window.objectAtPointVSB( event.point );
                //        auto curObject = window.objectAtPoint( event.point );
                //        if ( curObject !is null )
                //        {
                //            window.callHierarhically!( "onLeftMouseUp" )( curObject, event );
                //        }
                //    } catch ( Throwable e ) { assert( 0, e.toString() ); }
                //    return 0;
                //}
                    
                case WM_MOUSEMOVE: 
                {
                    Event event = { type: WM_MOUSEMOVE, mouseMove: { hwnd, message, wParam, lParam } };
                    event.mouseMove.drawer = *window;

                    // center
                    auto size = window.size();
                    event.mouseMove.to.x =    GET_X_LPARAM( lParam ) - size.w / 2;
                    event.mouseMove.to.y = -( GET_Y_LPARAM( lParam ) - size.h / 2 );
                    
                    //
                    window.on( &event );

                    // update window
                    RedrawWindow( hwnd, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW );
                    //InvalidateRect( hwnd, NULL, 0 );
                    //UpdateWindow( hwnd );
                    return 0;
                }
                    
                case WM_MOUSEWHEEL: 
                {
                    Event event = { type: WM_MOUSEWHEEL, mouseWheel: { hwnd, message, wParam, lParam } };
                    event.mouseWheel.drawer = *window;

                    //RECT wrect;
                    //GetWindowRect( hwnd, &wrect );
                    //RECT crect;
                    //GetClientRect ( hwnd, &crect );
                    POINT p = POINT( GET_X_LPARAM( lParam ), GET_Y_LPARAM( lParam ) );
                    ScreenToClient( hwnd, &p );

                    // center
                    auto size = window.size();
                    event.mouseWheel.to.x =    p.x - size.w / 2;
                    event.mouseWheel.to.y = -( p.y - size.h / 2 );
                    
                    //
                    window.on( &event );

                    //
                    RedrawWindow( hwnd, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW );
                    return 0;
                }

                case WM_TIMER: 
                {
                    if ( wParam == IDT_TIMER1 )
                    {
                        //InvalidateRect( hwnd, NULL, 0 );
                        RedrawWindow( hwnd, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW );
                    }
                    break;
                }

                    
                //case WM_SIZE: {
                //    try {
                //        Rect clientRect;
                //        GetClientRect( hwnd, cast( RECT* ) clientRect );

                //        window.selfArea.rect.size( clientRect.width, clientRect.height );

                //        emit!"onSize"( window, clientRect.width, clientRect.height );

                //        window.redraw();
                //    } catch ( Throwable e ) { assert( 0, e.toString() ); }
                //    return 0;
                //}
                    
                //case WM_MOVE: {
                //    try {
                //        emit!"onMove"( window, LOWORD( lParam ), HIWORD( lParam ) );
                //    } catch ( Throwable e ) { assert( 0, e.toString() ); }
                //    return 0;
                //}
                    
                //case WM_ACTIVATE: {
                //    try {
                //        if ( LOWORD( wParam ) == WA_INACTIVE )
                //            emit!"onDeactivate"( window );
                //        else
                //            emit!"onActivate"( window );
                //    } catch ( Throwable e ) { assert( 0, e.toString() ); }
                //    return 0;
                //}
                    
                case WM_CLOSE: 
                {
                    try {
                        //emit!"onClose"( window );
                        DestroyWindow( hwnd );
                    } catch ( Throwable e ) { assert( 0, e.toString() ); }
                    return 0;
                }
                    
                case WM_DESTROY: 
                {
                    try {
                        _forgetWindow( hwnd );

                        //if ( window.parent )
                        //    window.removeFromParent();

                        //if ( window.quitOnClose )
                        //    PostQuitMessage( 0 );

                        PostQuitMessage( 0 );
                    } catch ( Throwable e ) { assert( 0, e.toString() ); }
                    
                    return 0;
                }
                    
                default:
            }
        }

        return DefWindowProc( hwnd, message, wParam, lParam );
    }
}



/** */
class BackBuffer : RenderContext
{
    HDC      hdc;
    Rect     rect;
    OSWindow window;

    /** */
    this( HDC hdc, Rect rect, OSWindow window ) nothrow
    {
        this.hdc    = hdc;
        this.rect   = rect;
        this.window = window;
    }

    /** */
    void fillText( string text, POS x, POS y )
    {
        //
    }

    /** */
    void clip( Path2D path )
    {
        _clipPath = path;
    }


//    /** */
//    void center( Point praCenter, int x, int y )
//    {
//        _center.x = praCenter.x +  x;
//        _center.y = praCenter.y + -y;
//    }


//    /** */
//    Point center()
//    {
//        return _center;
//    }


//    /** */
//    Size size()
//    {
//        return Size( _w, _h );
//    }


//    /** */
//    void clear() nothrow
//    {
//        RECT rect;
//        rect.right  = _w;
//        rect.bottom = _h;

//        //HBRUSH brush = CreateSolidBrush( RGB( 0x44, 0x44, 0x44 ) );
//        HBRUSH brush = CreateSolidBrush( RGB( 0x00, 0x00, 0x0 ) );

//        FillRect( _hdc, &rect, brush );

//        DeleteObject( brush );
//    }


//    // Transfer the off-screen DC to the screen
//    void blt( OSWindow* window ) nothrow
//    {
//        BitBlt( window._hdc, 0, 0, _w, _h, _hdc, 0, 0, SRCCOPY );
//    }


//    /** */
//    void removeBackbuffer() nothrow
//    {
//        SelectObject( _hdc, oldBackBufferBitmap );
//        DeleteObject( backBufferBitmap );
//        DeleteDC ( _hdc );
//    }    


//    void color( Color color )
//    {
//        pen( color );
//    }


//    void pen( Color color )
//    {
//        HPEN hpen = CreatePen( PS_SOLID, _pen_w, color.windowsCOLORREF );
//        auto praPen = SelectObject( _hdc, hpen );
//        DeleteObject( praPen );
//    }


//    void pen( Color color, int w )
//    {
//        _pen_w = w;
//        HPEN hpen = CreatePen( PS_SOLID, w, color.windowsCOLORREF );
//        auto praPen = SelectObject( _hdc, hpen );
//        DeleteObject( praPen );
//    }


//    void pen( Color color, PenType penType, int w )
//    {
//        _pen_w = w;
//        HPEN hpen = CreatePen( penType, w, color.windowsCOLORREF );
//        auto praPen = SelectObject( _hdc, hpen );
//        DeleteObject( praPen );
//    }


//    void pen( ref Pen pen )
//    {
//        _pen_w = pen.width;
//        HPEN hpen = CreatePen( pen.type, pen.width, pen.color.windowsCOLORREF );
//        auto praPen = SelectObject( _hdc, hpen );
//        DeleteObject( praPen );
//    }


//    void moveTo( int x, int y )
//    {
//        Point p = center + Point( x, -y );
//        MoveToEx( _hdc, p.x, p.y, NULL );
//    }


//    void lineTo( int x, int y )
//    {
//        Point p = center + Point( x, -y );
//        LineTo( _hdc, p.x, p.y );
//    }


//    void point( POS x, POS y, Color color )
//    {
//        Point p = center + Point( x, -y );
//        SetPixel( _hdc, p.x, p.y, color.windowsCOLORREF );
//    }


//    void rectangle( int w, int h )
//    {
//        // Center ot the Vid
//        Point cen = this.center;

//        version ( Polyline )
//        {
//            // top left
//            Point p = cen - Point( w / 2, h / 2 );

//            SetPolyFillMode( _hdc, WINDING );
//            auto brush = CreateSolidBrush( GetDCPenColor( _hdc ) );
//            auto oldBrush = SelectObject( _hdc, brush ); 

//            // rectangle cd x gh
//            Point[5] points;
//            points[0] = p + Point(  0,  0 );  // start
//            points[1] = p + Point(  w,  0 );  // to right
//            points[2] = p + Point(  w,  h );  // to bottom
//            points[3] = p + Point(  0,  h );  // to left
//            points[4] = p + Point(  0,  0 );  // to top
//            Polyline( _hdc, cast( POINT* ) points.ptr, 5 );
//        }
//        else
//        {
//            RECT rect = { 
//                cen.x - w/2, 
//                cen.y - h/2, 
//                cen.x + w/2, 
//                cen.y + h/2 
//            };
//            //auto brush = CreateSolidBrush( GetDCPenColor( _hdc ) );
//            //auto brush = CreateSolidBrush( RGB( 0xCC, 0xCC, 0xCC ) );
//            auto pen = GetCurrentObject( _hdc, OBJ_PEN );
//            LOGPEN logpen;
//            GetObject( pen, logpen.sizeof, &logpen );
//            auto brush = CreateSolidBrush( logpen.lopnColor );
//            FrameRect( _hdc, &rect, brush );
//            DeleteObject( brush );
//        }
//    }


//    void rectangle( int l, int t, int r, int b )
//    {
//        import std.math : abs;

//        Point cen = this.center;

//        version ( Polyline )
//        {
//            // rectangle cd x gh
//            Point[5] points;
//            points[0] = cen + Point( l, -t );  // start
//            points[1] = cen + Point( r, -t );  // to right
//            points[2] = cen + Point( r, -b );  // to bottom
//            points[3] = cen + Point( l, -b );  // to left
//            points[4] = cen + Point( l, -t );  // to top

//            // 
//            Polyline( _hdc, cast( POINT* ) points.ptr, 5 );
//        }
//        else
//        {
//            RECT rect = { 
//                cen.x + l, 
//                cen.y + t, 
//                cen.x + r, 
//                cen.y + b 
//            };
//            //auto brush = CreateSolidBrush( GetDCPenColor( _hdc ) );
//            //auto brush = CreateSolidBrush( RGB( 0xCC, 0xCC, 0xCC ) );
//            auto pen = GetCurrentObject( _hdc, OBJ_PEN );
//            LOGPEN logpen;
//            GetObject( pen, logpen.sizeof, &logpen );
//            auto brush = CreateSolidBrush( logpen.lopnColor );
//            FrameRect( _hdc, &rect, brush );
//            DeleteObject( brush );
//        }
//    }


//    void rectangleFilled( int w, int h, Color color )
//    {
//        // Center ot the Vid
//        Point cen = this.center;

//        version ( Polyline )
//        {
//            // top left
//            Point p = cen - Point( w / 2, h / 2 );

//            // rectangle cd x gh
//            Point[5] points;
//            points[0] = p + Point(  0,  0 );  // start
//            points[1] = p + Point(  w,  0 );  // to right
//            points[2] = p + Point(  w,  h );  // to bottom
//            points[3] = p + Point(  0,  h );  // to left
//            points[4] = p + Point(  0,  0 );  // to top

//            // Fill Mode
//            SetPolyFillMode( _hdc, WINDING );
//            auto brush = CreateSolidBrush( color.windowsCOLORREF );
//            auto oldBrush = SelectObject( _hdc, brush ); 

//            // 
//            Polygon( _hdc, cast( POINT* ) points.ptr, 5 );

//            // 
//            SelectObject( _hdc, oldBrush ); 
//            DeleteObject( brush);
//        }
//        else
//        {
//            // Fill Mode
//            auto brush = CreateSolidBrush( color.windowsCOLORREF );
//            auto oldBrush = SelectObject( _hdc, brush ); 

//            Rectangle( 
//                _hdc, 
//                cen.x - w/2, 
//                cen.y - h/2, 
//                cen.x + w/2, 
//                cen.y + h/2 
//            );

//            // 
//            SelectObject( _hdc, oldBrush ); 
//            DeleteObject( brush);
//        }
//    }


//    void rectangleFilled( int l, int t, int r, int b, Color color )
//    {
//        import std.math : abs;

//        // Center ot the Vid
//        Point cen = this.center;

//        version ( Polyline )
//        {
//            // rectangle cd x gh
//            Point[5] points;
//            points[0] = cen + Point( l, -t );  // start
//            points[1] = cen + Point( r, -t );  // to right
//            points[2] = cen + Point( r, -b );  // to bottom
//            points[3] = cen + Point( l, -b );  // to left
//            points[4] = cen + Point( l, -t );  // to top

//            // Fill Mode
//            SetPolyFillMode( _hdc, WINDING );
//            auto brush = CreateSolidBrush( color.windowsCOLORREF );
//            auto oldBrush = SelectObject( _hdc, brush ); 

//            // 
//            //Polyline( _hdc, points.ptr, 5 );
//            Polygon( _hdc, cast( POINT* ) points.ptr, 5 );

//            // 
//            SelectObject( _hdc, oldBrush ); 
//            DeleteObject( brush);
//        }
//        else
//        {
//            // Fill Mode
//            auto brush = CreateSolidBrush( color.windowsCOLORREF );
//            auto oldBrush = SelectObject( _hdc, brush ); 

//            Rectangle( 
//                _hdc, 
//                cen.x + l, 
//                cen.y + t, 
//                cen.x + r, 
//                cen.y + b 
//            );

//            // 
//            SelectObject( _hdc, oldBrush ); 
//            DeleteObject( brush);            
//        }
//    }


//    //void rectangleFilled( Rect* rect, Color color )
//    //{
//    //    import std.math : abs;

//    //    // Center ot the Vid
//    //    Point cen = this.center;

//    //    // Fill Mode
//    //    auto brush = CreateSolidBrush( color.windowsCOLORREF );
//    //    auto oldBrush = SelectObject( _hdc, brush ); 

//    //    Rectangle( 
//    //        _hdc, 
//    //        cen.x + l, 
//    //        cen.y + t, 
//    //        cen.x + r, 
//    //        cen.y + b 
//    //    );

//    //    // 
//    //    SelectObject( _hdc, oldBrush ); 
//    //    DeleteObject( brush);            
//    //}


//    void triangleFromCenterFilled( Point p1, Point p2, Color color )
//    {
//        // center
//        // p1
//        // p2

//        // Center ot the Vid
//        Point cen = this.center;
        
//        // rectangle cd x gh
//        Point[4] points;
//        points[0] = cen;       // start
//        points[1] = cen + p1;  // to p1
//        points[2] = cen + p2;  // to p2
//        points[3] = cen;       // end

//        // Fill Mode
//        SetPolyFillMode( _hdc, WINDING );
//        auto brush = CreateSolidBrush( color.windowsCOLORREF );
//        auto oldBrush = SelectObject( _hdc, brush ); 

//        // 
//        Polygon( _hdc, cast( POINT* ) points.ptr, 4 );

//        // 
//        SelectObject( _hdc, oldBrush ); 
//        DeleteObject( brush);
//    }


//    void symbol( wchar wc, int l, int t, int r, int b )
//    {
//        import std.math : abs;

//        // Center ot the Vid
//        Point cen = this.center;

//        RECT rect = {
//            cen.x + l, 
//            cen.y + t, 
//            cen.x + r, 
//            cen.y + b 
//        };

//        HFONT font = Font( "Arial", abs( t ) + abs( b ) ).toWindowsFont();
//        HFONT prafont = SelectObject( _hdc, font );

//        ExtTextOutW(
//            _hdc,
//            rect.left,
//            rect.top,
//            0,
//            &rect,
//            cast( LPCWSTR ) &wc,
//            1,
//            NULL
//        );

//        SelectObject( _hdc, prafont );
//        DeleteObject( font );
//    }


//    void text( string s, int w, int h, ref TextSet textSet )
//    {
//        //
//    }


//    ref uint w()
//    {
//        return _w;
//    }


//    ref uint h()
//    {
//        return _h;
//    }


//    void clipRect( int cx, int cy, int w, int h )
//    {
//        int topLeftX;
//        int topLeftY;
//        topLeftX = _center.x + cx - w/2;
//        topLeftY = _center.y + cy - h/2;
//        BeginPath( _hdc );
//        MoveToEx( _hdc, topLeftX,     topLeftY,     NULL );  // top left
//        LineTo(   _hdc, topLeftX + w, topLeftY     );  // top right
//        LineTo(   _hdc, topLeftX + w, topLeftY + h );  // bottom right
//        LineTo(   _hdc, topLeftX,     topLeftY + h );  // bottom left
//        LineTo(   _hdc, topLeftX,     topLeftY     );  // top left. finish
//        EndPath( _hdc );
//        SelectClipPath( _hdc, RGN_AND );
//    }

//    void set()
//    {
//        //
//    }


//    void vid()
//    {
//        if ( document !is null )
//        {
//            //document.body.update();
//            document.body.vid( this );
//            //document.body.dump();
//        }
//    }


//    int on( Event* event ) nothrow
//    {
//        return 0;
//    }


//    Element* getFocused()
//    {
//        return null;
//    }


//    HDC   _hdc;
//private:
//    uint  _w;
//    uint  _h;
//    Point _center;
//    uint  _pen_w;

//    HDC  oldBackBufferBitmap;
//    HDC  backBufferBitmap;
}



/** */
pragma( inline )
void emit( string method, T, ARGS... )( T This, ARGS args )
{
    import std.exception : enforce;
    mixin( "enforce( This )." ~  method ~ "( args );" );
}


/** */
Element* findObjectAt( Element* root, Point p )
{
    auto element = root;
    Element* child;

    if ( element.hitTest( p ) )
    {
        // in childs
        if ( element.firstChild !is null )
        for ( auto e = element.firstChild; e !is null; e = e.nextSibling )
        {
             child = findObjectAt( e, p );

             if ( child !is null )
             {
                return child;
             }
        }

        return element;
    }

    return null;
}


/** */
void renderElementsInRect( RenderContext* ctx, Document* doc, Rect rect )
{
    // find elements in rect
    // render each
    findElementsInRect( doc, rect)
        .forEach( (e) => {
            e.draw( ctx );
        });
}

/** */
NodeList findElementsInRect( Document* doc, Rect rect )
{
    // document
    //   body
    //     e1
    //     e2
    //     e3
    //       e4
    //     e5
    //
    // [body, e1, e2, e3, e4, e5]
    //
    // if rect contains e4:
    //   [body, e3, e4]

    NodeList lst;

    walkInDepth( &doc.body, (e) => {
        if ( rectInRect( e.computed.absoluteRect, rect ) )
            lst ~= e;
    } );

    return lst;
}

/** */
bool rectInRect( Rect a, Rect b )
{
    // +----------+
    // | b        |
    // |  +---+   |
    // |  | a |   |
    // |  +---+   |
    // +----------+

    // 1
    // +----------+
    // | b        |
    // |  +-------|
    // |  | a     |
    // |  |       |
    // +----------+

    // 2
    // +----------+
    // | b        |
    // |------+   |
    // |    a |   |
    // |      |   |
    // +----------+

    // 3
    // +----------+
    // | b|       |
    // |  |       |
    // |  | a     |
    // |  +-------|
    // +----------+

    // 4
    // +----------+
    // | b    |   |
    // |      |   |
    // |    a |   |
    // |------+   |
    // +----------+

    if ( 
        // 1
        (
            a.left >= b.left && a.left < b.right &&
            a.top  >= b.top  && a.top  < b.bottom
        ) ||
        // 2
        (
            a.right >= b.left && a.right < b.right &&
            a.top   >= b.top  && a.top   < b.bottom
        ) ||
        // 3
        (
            a.left   >= b.left && a.left   < b.right &&
            a.bottom >= b.top  && a.bottom < b.bottom
        ) ||
        // 4
        (
            a.right  >= b.left && a.right  < b.right &&
            a.bottom >= b.top  && a.bottom < b.bottom
        )
       )
        return true;

    return false;
}
