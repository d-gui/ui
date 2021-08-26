import deps.glfw;
import deps.gl3;
import core.stdc.stdio  : printf;
import core.stdc.stdlib : exit;
import ui.app           : App;
import ui.line          : drawLine;
import ui.glerrors      : checkGlError;
import std.range;
import std.math;
import std.stdio : writeln;


int main( string[] args ) 
{
	return App!drawFrame( args );
}


void drawFrame( T )( ref T window )
{
	//debug writeln( __FUNCTION__ );

    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

	int width, height;
	glfwGetFramebufferSize( window, &width, &height );
	glViewport( 0, 0, width, height );

	// Polygon
	Polygon polygon =
	[
		Vec2i( 400, 100 ), // top
		Vec2i( 700, 300 ), // right
		Vec2i( 100, 300 ), // left
	];

	//drawLine( 100, 300, 700, 300, 0xFF, 0xFF, 0xFF, 0xFF );
	drawPolygon( polygon, 0xFFFFFFFF );

	// fill polygon
	//fillPolygon( polygon, 0xFFFFFFFF );
	fillPolygon4( polygon, 0xFFFFFFFF );
}


struct Vec2i
{
	int x;
	int y;

	Vec2i opBinary( string op : "+" )( Vec2i b )
	{
		return 
			Vec2i(
				x + b.x,
				y + b.y
			);
	}

	Vec2i opBinary( string op : "-" )( Vec2i b )
	{
		return 
			Vec2i(
				x - b.x,
				y - b.y
			);
	}
}


struct Line
{
	Vec2i a;
	Vec2i b;

	auto x( int y )
	{
		// x = k*y + shift; 
		// k = ( x - shift ) / y;
		// shift = x - k*y; 
		// shift = x; // y = 0
		auto nb = b - a;

		auto shiftb = a.x;

		auto kb = ( cast( float ) nb.x / nb.y );
		auto x = cast( int ) round( kb * (y - a.y) + shiftb );

		return x;
	}
}


struct Scanline
{
	Vec2i a;
	Vec2i b;
	Vec2i c;

	auto opApply( int delegate( ref Line scanline ) dg )
	{
		int result = 0;

		auto ab = Line( a, b );
		auto ac = Line( a, c );
		Line scanline;

		foreach ( y; a.y .. b.y )
		{
			//scanline = 
			//	Line( 
			//		Vec2i( ab.x( y ), y ), 
			//		Vec2i( ac.x( y ), y ) 
			//	);
			scanline.a.x = ab.x( y );
			scanline.b.x = ac.x( y );
			scanline.a.y = scanline.b.y = y;

			result = dg( scanline );

			if ( result )
				break;
		}

		return result;
	}
}


struct Scanline4
{
	Vec2i a;
	Vec2i b;
	Vec2i c;
	Vec2i d;

	// find top-left point - is A
	// get 2 near vertices

	auto opApply( int delegate( ref Line scanline ) dg )
	{
		int result = 0;

		auto ab = Line( a, b );
		auto ac = Line( a, c );
		Line scanline;

		foreach ( y; a.y .. b.y )
		{
			//scanline = 
			//	Line( 
			//		Vec2i( ab.x( y ), y ), 
			//		Vec2i( ac.x( y ), y ) 
			//	);
			scanline.a.x = ab.x( y );
			scanline.b.x = ac.x( y );
			scanline.a.y = scanline.b.y = y;

			result = dg( scanline );

			if ( result )
				break;
		}

		return result;
	}
}


void drawLine( Line line, uint color )
{
	drawLine( 
		line.a.x, line.a.y, 
		line.b.x, line.b.y, 
		color 
	);
}


// static
//   StaticPolygon!3 polygon;
struct StaticPolygon( size_t N )
{
	Vec2i[ N ] vertices;
	alias vertices this;

	this( Vec2i[] vs )
	{
		opAssign( vs );
	}

	void opAssign( ref Vec2i[] vs )
	{
		foreach ( i, ref v; vs[ 0 .. N ] )
		{
			vertices[i] = v;
		}
	}
}


// dynamic
struct Polygon
{
	Vec2i[] vertices;
	alias vertices this;

	this( Vec2i[] vs )
	{
		opAssign( vs );
	}

	void opAssign( ref Vec2i[] vs )
	{
		vertices = vs;
	}
}


void drawPolygon( T )( ref T vertices, uint color )
{
	foreach ( ref v; chain( vertices[], vertices[ 0 .. 1 ] ).slide( 2 ) )
	{
		drawLine( v[0].x, v[0].y, v[1].x, v[1].y, color );
	}
}


void fillTriangle( T )( T vertices, uint color )
{
	// top vertex
	auto a = vertices[0];

	// near vertices: ab, ac
	auto b = vertices[1];
	auto c = vertices[2];

	//
	foreach ( ref scanline; Scanline( a, b, c ) )
	{
		drawLine( scanline, color );
	}
}


void fillPolygon( T )( T vertices, uint color )
{
	// top vertex
	auto a = vertices[0];

	// near vertices: ab, ac
	auto b = vertices[1];
	auto c = vertices[2];

	//
	foreach ( ref scanline; Scanline( a, b, c ) )
	{
		drawLine( scanline, color );
	}
}


void fillPolygon4( T )( ref T vertices, uint color )
{
	// find top vertex
	auto topVertexIndex = findTopVertex( vertices );
	// top vertex
	auto a = vertices[ topVertexIndex ];

	// near indices
	size_t bi;
	size_t ci;
	nearIndices( vertices.length - 1, topVertexIndex, &bi, &ci );
	// near vertices: ab, ac
	auto b = vertices[ bi ];
	auto c = vertices[ ci ];

	//
	foreach ( ref scanline; Scanline( a, b, c ) )
	{
		drawLine( scanline, color );
	}
}


auto findTopVertex( T )( ref T vertices )
{
	int    topY;
	size_t topIndex;

	foreach ( i, ref v; vertices )
	{
		if ( v.y < topY )
		{
			topY = v.y;
			topIndex = i;
		}
	}

	return topIndex;
}


void nearIndices( size_t last, size_t i, size_t* b, size_t* c )
{
	if ( i == 0 )
		*b = last;
	else
		*b = i - 1;

	if ( i == last )
		*c = 0;
	else
		*c = i + 1;
}
