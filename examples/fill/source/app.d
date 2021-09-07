import deps.glfw;
import deps.gl3;
import core.stdc.stdio  : printf;
import core.stdc.stdlib : exit;
import ui.app           : App;
import ui.line          : drawLine;
import ui.lines         : drawLines;
import ui.lines         : Line, Vec2i, Point, XXLine, XXLines, INDEX, COORD, COLOR;
import ui.glerrors      : checkGlError;
import std.range;
import std.math;
import std.stdio : writeln;
import std.algorithm : sort;
import std.algorithm : each;


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

	// Triangle
	//        .
	//       / \
	//      /   \
	//     /     .
	//    /     /
	//   /   /
	//  / /
	// .
	Polygon triangle =
	[
		Vec2i( 400, 100 ), // top
		Vec2i( 700, 300 ), // right
		Vec2i( 100, 500 ), // left
	];

	// Hexagon
	//   /\
	// |    |
	// |    |
	//   \/
	//   
	Polygon hexagon1 =
	[
		Vec2i( 400, 100 ), // top
		Vec2i( 700, 200 ), // right top
		Vec2i( 700, 300 ), // right bottom
		Vec2i( 400, 400 ), // bottom
		Vec2i( 100, 300 ), // left bottom
		Vec2i( 100, 200 ), // left top
	];

	// Hexagon 2
	//   ---
	// /     \
	// \     /
	//   ---
	Polygon hexagon2 =
	[
		Vec2i( 200, 100 ), // top
		Vec2i( 600, 100 ), // top
		Vec2i( 700, 300 ), // right
		Vec2i( 600, 500 ), // bottom
		Vec2i( 200, 500 ), // bottom
		Vec2i( 100, 300 ), // left 
	];

	// Star
	Polygon star =
	[
		Vec2i( 384, 105 ), // top
		Vec2i( 480, 259 ), // right
		Vec2i( 682, 281 ), // right
		Vec2i( 540, 415 ), // right
		Vec2i( 580, 590 ), // bottom
		Vec2i( 400, 515 ), // bottom
		Vec2i( 217, 600 ), // bottom
		Vec2i( 248, 418 ), // left
		Vec2i( 100, 294 ), // left
		Vec2i( 300, 265 ), // left
	];

	// Glyph A
	Polygon glyphA =
	[
		// A
		Vec2i( 260,  98 ), // top
		Vec2i( 377, 432 ), 
		Vec2i( 335, 435 ), 
		Vec2i( 335, 435 ), 
		Vec2i( 303, 335 ), 
		Vec2i( 175, 335 ), 
		Vec2i( 143, 434 ), 
		Vec2i(  99, 432 ), 
		Vec2i( 217,  98 ),
	];

	Polygon glyphAhole =
	[
		// Hole
		Vec2i( 237, 141 ), // top
		Vec2i( 291, 299 ), 
		Vec2i( 185, 299 ), 
	];


	//auto polygon = triangle;
	//auto polygon = hexagon1;
	//auto polygon = hexagon2;
	//auto polygon = star;
	auto polygon = glyphA;
	auto polygonHole = glyphAhole;

	//drawLine( 100, 300, 700, 300, 0xFF, 0xFF, 0xFF, 0xFF );
	drawPolygon( polygon, 0xFFFFFFFF );

	// fill polygon
	//fillPolygon( polygon, 0xFFFFFFFF );
	//VPolygon( polygon ).fill( 0xFFFFFFFF );
	//VPolygon2( polygon ).fill( 0xFFFFFFFF );
	VPolygon3( polygon, polygonHole ).fill( 0xFFFFFFFF );
}


struct Scanline
{
	// draw horizontal line from l to r
	Line l;
	Line r;

	auto opApply( int delegate( ref Line scanline ) dg )
	{
		int result = 0;

		Line scanline;

		// if r is left then change for l will be left
		if ( l.a.x > r.a.x )
		{
			auto tmp = l;
			l = r;
			r = tmp;
		}

		// a .. b filling
		auto a = l.a;
		if ( r.a.y > l.a.y )
			a = r.a;

		auto b = l.b;
		if ( r.b.y < l.b.y )
			b = r.b;

		foreach ( y; a.y .. b.y )
		{
			//scanline = 
			//	Line( 
			//		Vec2i( ab.x( y ), y ), 
			//		Vec2i( ac.x( y ), y ) 
			//	);
			scanline.a.x = l.x( y );
			scanline.b.x = r.x( y );
			scanline.a.y = scanline.b.y = y;

			result = dg( scanline );

			if ( result )
				break;
		}

		return result;
	}
}


void drawScanLines( Line l, Line r, COLOR color )
{
	// wich point at top
	// wich point at bottom
	// a .. b filling
	Point a = cast( Point ) l.a;
	if ( r.a.y > l.a.y )
		a = cast( Point ) r.a;

	Point b = cast( Point ) l.b;
	if ( r.b.y < l.b.y )
		b = cast( Point ) r.b;

	// array for draw
	Line[] lines;
	foreach ( y; a.y .. b.y )
	{
		//scanline = 
		//	Line( 
		//		Vec2i( ab.x( y ), y ), 
		//		Vec2i( ac.x( y ), y ) 
		//	);

		lines ~= Line( 
			Point( l.x( y ), y ),
			Point( r.x( y ), y ), 
		);
	}	

	// draw
	drawLines( lines, color );
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


// Fill via Cut
struct VPolygon2
{
	Polygon polygon;

	enum DIR
	{
		UP,
		DOWN
	}

	void fill( COLOR color )
	{
		// Create array of Lines 
		//   size = 400 - 100 = ( bottom.y - top.y )
		//   Fill with Line( 0,0, width,0 )
		//   Optimized:
		//     ( x1, x2 )[ size ] = (int, int), (int, int)
		// Scan contour
		//   Get next_point
		//   If next_point is go down
		//     If next_point between x1, x2
		//       Update right x
		//     else
		//       Switch buffer or Create
		//         If next_point between x1, x2
		//           Update right x
		//         else
		//           loop
		//   If next_point is go up
		//     Update left x 


		// get max, min y
		COORD maxy; INDEX maxyi;
		COORD miny; INDEX minyi;

		foreach ( i, ref p; polygon.vertices )
		{
			if ( p.y > maxy )
			{
				maxy  = p.y;
				maxyi = i;
			}

			if ( p.y < miny )
			{
				miny  = p.y;
				minyi = i;
			}
		}

		XXLines xxlines;
		xxlines.reserve( ( maxy - miny ) * 4 );

		xxlines.length = maxy - miny + 1;

		// scan points + first point as pairs: ( pre, cur )
		foreach ( ref pp; chain( polygon.vertices, [ polygon.vertices[0] ] ).slide( 2 ) )
		{
			auto pre = pp[0];
			auto cur = pp[1];

			DIR dir =
				( cur.y > pre.y ) ?
					DIR.DOWN :
					DIR.UP ;

			// up-down
			auto fromy = pre.y;
			auto toy   = cur.y;

			// down-up do swap
			if ( pre.y > cur.y )
			{
				fromy = cur.y;
				toy   = pre.y;
			}

			foreach ( y; iota( fromy, toy ) )
			{
				// if go down
				//   update x2
				// if go up
				//   update x1
				if ( dir == DIR.DOWN )
				{
					size_t idx = y - miny;

					auto xx = &xxlines[ idx ];
					auto x  = Line( pre, cur ).x( y );

					// first pass
					L_check:
					if ( xx.x1 == 0 && xx.x2 == 0 )
					{
						xx.x2 = x;
						xx.y  = y;
					}

					// 2nd pass, ...
					else
					{
						// add line in next block
						if ( xx.nextIndex == 0 )
						{
							xxlines ~= XXLine( 0, x, y );
							xx.nextIndex = xxlines.length-1;
						}

						// go and check next block
						else
						{
							idx = xx.nextIndex;
							xx = &xxlines[ idx ];
							goto L_check;
						}
					}
				}

				// DIR.UP
				else
				{
					size_t idx = y - miny;

					auto xx = &xxlines[ idx ];
					auto x  = Line( pre, cur ).x( y );

					// x between x1, x2
					L_next:
					if ( x.between( xx.x1, xx.x2 ) )
					{
						xx.x1 = x;
					}

					// check next block
					else
					{
						idx = xx.nextIndex;
						xx = &xxlines[ idx ];
						goto L_next;
					}
				}
			}
		}

		// draw
		drawLines( xxlines, color );
	}
}


// Fill via Scanline
struct VPolygon3
{
	Polygon polygon;
	Polygon hole;

	enum FLAGS
	{
		NONE = 0b0000_0000,
		DOWN = 0b0000_0001,
		HOLE = 0b0000_0010
	}

	struct SCLine
	{
		Line  line;
		alias line this;
		FLAGS flags;
	}

	void fill( COLOR color )
	{
		// get max, min y
		COORD maxy; INDEX maxyi;
		COORD miny; INDEX minyi;

		foreach ( i, ref p; polygon.vertices )
		{
			if ( p.y > maxy )
			{
				maxy  = p.y;
				maxyi = i;
			}

			if ( p.y < miny )
			{
				miny  = p.y;
				minyi = i;
			}
		}

		//
		SCLine[] lines;
		lines.reserve( polygon.vertices.length );

		Line[] alines;
		alines.reserve( polygon.vertices.length );

		// create lines
		// scan points as pairs: ( pre, cur )
		foreach ( ref pp; chain( polygon.vertices, [ polygon.vertices.front ] ).slide( 2 ) )
		{
			auto pre = pp[0];
			auto cur = pp[1];

			//
			if ( cur.y > pre.y )
				lines ~= SCLine( Line( pre, cur ), FLAGS.DOWN );
			else
				lines ~= SCLine( Line( cur, pre ), FLAGS.NONE );
		}

		foreach ( ref pp; chain( hole.vertices, [ hole.vertices.front ] ).slide( 2 ) )
		{
			auto pre = pp[0];
			auto cur = pp[1];

			//
			if ( cur.y > pre.y )
				lines ~= SCLine( Line( pre, cur ), FLAGS.HOLE | FLAGS.DOWN );
			else
				lines ~= SCLine( Line( cur, pre ), FLAGS.HOLE );
		}

		// sort
		lines.sort!"a.line.a.y < b.line.a.y";

		// fill
		size_t a = 0;
		size_t b = lines.length;
		
		foreach ( y; iota( miny, maxy ) )
		{
			struct X
			{
				COORD x;
				FLAGS flags;
			}

			X[] xx;

			foreach ( ref line; lines )
			{
				// collect x to array
				if ( y.betweenExcludeB( line.a.y, line.b.y ) )
				{
					xx ~= X( line.x( y ), line.flags );
				}
			}

			//
			xx.sort!"a.x < b.x";

			// prepare lines for draw
			foreach ( ref xxp; xx.chunks( 2 ) )
			{
				alines ~=
					Line(
						Point( xxp[0].x, y ),
						Point( xxp[1].x, y )
					);
			}
		}

		// draw
		drawLines( alines, color );
	}
}


pragma( inline, true )
auto between( T )( T x, T a, T b )
{
	return 
		( a <= x ) && ( x <= b );
}


pragma( inline, true )
auto betweenExcludeB( T )( T x, T a, T b )
{
	return 
		( a <= x ) && ( x < b );
}


struct VPolygon
{
	Polygon polygon;


	void fill( COLOR color )
	{
		// find top vertex
		auto ai = findTopVertex();
		// top vertex
		auto a = polygon.vertices[ ai ];

		// near indices
		// find next vertex at left
		auto li = findLeftVertex( ai );
		auto b = polygon.vertices[ li ];

		// find next vertex at right
		auto ri = findRightVertex( ai );
		auto c = polygon.vertices[ ri ];

		//
		auto l = Line( a, b );
		auto r = Line( a, c );

		// 
		while ( 1 )
		{
			// if r is left then change for l will be left
			if ( l.a.x > r.a.x )
			{
				auto tmp = l;
				l = r;
				r = tmp;
			}

			//	
			drawScanLines( l, r, color );

			//
			INDEX nexti;
			Point nextp;

			// who ended l ot r
			// left ended
			if ( l.b.y < r.b.y )
			{
				nexti = findLowerVertex( li );

				//
				if ( nexti != -1 )
				{
					nextp = polygon.vertices[ nexti ];
					l = Line( l.b, nextp );
					li = nexti;
					continue;
				}
				else
				{
					break;
				}
			}

			// right ended
			else
			{
				nexti = findLowerVertex( ri );

				//
				if ( nexti != -1 )
				{
					nextp = polygon.vertices[ nexti ];
					r = Line( r.b, nextp );
					ri = nexti;
					continue;
				}
				else
				{
					break;
				}
			}
		}
	}


	auto findTopVertex()
	{
		COORD topY;
		INDEX topIndex;

		foreach ( i, ref v; polygon.vertices )
		{
			if ( v.y < topY )
			{
				topY = v.y;
				topIndex = i;
			}
		}

		return topIndex;
	}


	INDEX findLeftVertex( INDEX ai )
	{
		if ( ai == 0 )
			return polygon.vertices.length - 1;
		else
			return ai - 1;
	}


	INDEX findRightVertex( INDEX ai )
	{
		ai += 1;

		if ( ai == polygon.vertices.length )
			return 0;
		else
			return ai;
	}

	INDEX findLowerVertex( INDEX ai )
	{
		auto a = polygon.vertices[ ai ];

		// try left
		{
			auto bi = findLeftVertex( ai );
			auto b = polygon.vertices[ bi ];

			if ( b.y > a.y )
				return bi;
		}

		// try right
		{
			auto bi = findRightVertex( ai );
			auto b = polygon.vertices[ bi ];

			if ( b.y > a.y )
				return bi;
		}

		return -1;
	}
}


size_t nextVertex( T )( ref T vertices, size_t i )
{
	size_t i1;
	size_t i2;
	nearIndices( vertices.length - 1, i, &i1, &i2 );

	// next y > current y
	auto a  = vertices[ i ];
	auto v1 = vertices[ i1 ];
	auto v2 = vertices[ i2 ];

	if ( v1.y > a.y && v2.y > a.y  )
	{
		if ( v1.y < v2.y )
			return i1;
		else
			return i2;
	}
	else
	if ( v1.y > a.y )
		return i1;
	else
	if ( v2.y > a.y )
		return i2;
	else
		return -1; // FINISH
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
