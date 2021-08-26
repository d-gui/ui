module ftmisc;
/****************************************************************************
 *
 * ftmisc.h
 *
 *   Miscellaneous macros for stand-alone rasterizer (specification
 *   only).
 *
 * Copyright (C) 2005-2020 by
 * David Turner, Robert Wilhelm, and Werner Lemberg.
 *
 * This file is part of the FreeType project, and may only be used
 * modified and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


  /****************************************************
   *
   * This file is *not* portable!  You have to adapt
   * its definitions to your platform.
   *
   */

  /* memset */
  import bindbc.freetype;

//#define FT_LOCAL_DEF( x )   static x


  /* from include/freetype/fttypes.h */

  alias FT_Byte    = ubyte ;
  alias FT_Int     = int   ;
  alias FT_UInt    = uint  ;
  alias FT_Long    = long  ;
  alias FT_ULong   = ulong ;
  alias FT_F26Dot6 = long  ;
  alias FT_Error   = int   ;

auto FT_MAKE_TAG( T1, T2, T3, T4 )( T1 _x1, T2 _x2, T3 _x3, T4 _x4 )
{
    return
          ( ( cast( FT_ULong ) _x1 << 24 ) |
            ( cast( FT_ULong ) _x2 << 16 ) |
            ( cast( FT_ULong ) _x3 <<  8 ) |
              cast( FT_ULong ) _x4         );
}


  /* from include/freetype/ftsystem.h */

  alias FT_Memory = FT_MemoryRec_*;

  alias FT_Alloc_Func   = void* function( FT_Memory memory, long  size );
  alias FT_Free_Func    = void  function( FT_Memory memory, void* block );
  alias FT_Realloc_Func = void* function( FT_Memory  memory, long cur_size, long new_size, void* block );

  struct FT_MemoryRec_
  {
    void*            user;
    FT_Alloc_Func    alloc;
    FT_Free_Func     free;
    FT_Realloc_Func  realloc;
  }
  alias FT_MemoryRec = FT_MemoryRec_;


  /* from src/ftcalc.c */

version ( windows )
{
    alias FT_Int64 =long;
}
else
{
    alias FT_Int64 = long;
}


  static nothrow 
  FT_Long FT_MulDiv( FT_Long  a, FT_Long  b, FT_Long  c )
  {
    FT_Int   s;
    FT_Long  d;


    s = 1;
    if ( a < 0 ) { a = -a; s = -1; }
    if ( b < 0 ) { b = -b; s = -s; }
    if ( c < 0 ) { c = -c; s = -s; }

    d = 
      cast( FT_Long ) ( 
        ( c > 0 ) ? 
          ( cast(FT_Int64)a * b + ( c >> 1 ) ) / c :
          0x7FFFFFFFL 
      );

    return 
      ( s > 0 ) ? 
        d :
        -d;
  }


  static nothrow 
  FT_Long FT_MulDiv_No_Round( FT_Long  a, FT_Long  b, FT_Long  c )
  {
    FT_Int   s;
    FT_Long  d;


    s = 1;
    if ( a < 0 ) { a = -a; s = -1; }
    if ( b < 0 ) { b = -b; s = -s; }
    if ( c < 0 ) { c = -c; s = -s; }

    d = 
      cast( FT_Long )( 
        ( c > 0 ) ? 
          cast( FT_Int64 ) a * b / c :
          0x7FFFFFFFL 
      );

    return 
      ( s > 0 ) ? 
        d : 
        -d;
  }
