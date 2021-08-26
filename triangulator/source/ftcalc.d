module ftcalc;

import bindbc.freetype;

alias FT_UInt64 = ulong;


  nothrow 
  FT_Long FT_MulDiv_No_Round( FT_Long  a_, FT_Long  b_, FT_Long  c_ )
  {
    FT_Int     s = 1;
    FT_UInt64  a, b, c, d;
    FT_Long    d_;


    a = cast(FT_UInt64)a_;
    b = cast(FT_UInt64)b_;
    c = cast(FT_UInt64)c_;

    FT_MOVE_SIGN( a_, a, s );
    FT_MOVE_SIGN( b_, b, s );
    FT_MOVE_SIGN( c_, c, s );

    d = c > 0 ? a * b / c
              : 0x7FFFFFFFUL;

    d_ = cast(FT_Long)d;

    return s < 0 ? NEG_LONG( d_ ) : d_;
  }


pragma( inline, true )
auto FT_MOVE_SIGN( T1, T2, T3 )( ref T1 x, ref T2 x_unsigned, ref T3 s ) 
{
    if ( x < 0 )                         
    {                                    
      x_unsigned = 0U - (x_unsigned);    
      s          = -s;                   
    }                                    
}

auto NEG_LONG( T )( T a )
{
  return cast(long) ( -cast(ulong) ( a ) );
}

