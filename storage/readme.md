Storage
  size()


Storages
  Storage[] list();


System
  Stoages storages()


Storage
  size()
  read( block_size )
  seek( position )
  ables()


enum ABLES
{
    NONE     = 0b000_0000;
    CAN_SIZE = 0b000_0001;
    CAN_READ = 0b000_0010;
    CAN_SEEK = 0b000_0100;
}


abstract 
class Storage
{
  size()
  read( block_size )
  seek( position )
  ables()
}

class HddStorage : Storage
{
  size()
  read( block_size )
  seek( position )
  ables()
}

class NetStorage : Storage
{
  size()
  read( block_size )
  seek( position )
  ables()
}


Widget
StorageWidget
StoragesWidget

Widget
  childs[]        | parallel
  childs_rects[]  |

Widget
  rect


in_rect()
  rect.x <= x && x < rect.x2
  rect.y <= y && y < rect.y2

  SIMD:
    l  t  r  b
    32 32 32 32 - 128 bit
    x  y  x  y
    32 32 32 32
    >= >= <  <

    l  t  r  b
    x  y  x  y
    >= >= <  <

    gte r32_r32 m32_m32
    jz
    lt  r32_r32 m32_m32
    jz

    l  t  w  h
    32 32 32 32 - 128 bit
    x  y 
    32 32
    x - l, y - t
    < w, < h
    ( x - l ) < w, ( y - t ) < h
    ( l + w ) < x, ( t + h ) < y

    //
    t w  x
    0 1  0
    x - t - w <0 OK
    0 - 0 - 1 <0 OK
    0 1  1
    1 - 0 - 1 =0 FAIL
    0 1  2
    2 - 0 - 1 >0 FAIL
    0 0  1
    1 - 0 - 0 >0 FAIL
    1 2  1
    1 - 1 - 2 <0 OK
    1 2  2
    2 - 1 - 2 <0 OK - FAIL
    1 2  3
    3 - 1 - 2 =0 FAIL
    -1 2  2
    2 - -1 - 2 >0 FAIL
    -1 3  1
    1 - -1 - 3 <0 OK
    1 2  0
    0 - 1 - 2 <0 OK - FAIL

    t + w - x >0
    0 1  0
    0 + 1 - 0 >0 OK
    0 1  2
    0 + 1 - 2 <0 FAIL
    1 2  0
    1 + 2 - 0 >0 OK

    l  t  r  b
    x  y  x  y
    <= <= >  >
    rect
      lt
        l <= x
        t <= y
        pcmpgtd lt, xy
          lt == 0          OK
          lt == 0xFFFFFFFF FAIL
      rb
        r > x
        b > y
        pcmpgtd rb, xy
          rb == 0xFFFFFFFF OK
          rb == 0          FAIL

    l  t  r  b
    x  y  x  y
    -  -  -  -
    l-x < 0     -
    t-y < 0     -
    r-x >= 0    +
    b-y >= 0    +

    1 sub
    1 bits test
    1 jz

    1 cmp l x
    1 jz
    1 cmp t y
    1 jz
    1 cmp r x
    1 jz
    1 cmp b y
    1 jz

    aaaa > bbbb
    __m64 _mm_cmpgt_pi16 (__m64 a, __m64 b)
    #include <mmintrin.h>
    Instruction: pcmpgtw mm, mm

    __m128 _mm_cmpgt_ps (__m128 a, __m128 b)
    #include <xmmintrin.h>
    Instruction: cmpps xmm, xmm, imm8    

    __m128i _mm_lddqu_si128 (__m128i const* mem_addr)
    #include <pmmintrin.h>
    Instruction: lddqu xmm, m128

    MMX 
    a >= b
    __m64 _mm_cmpgt_pi32 (__m64 a, __m64 b)
    #include <mmintrin.h>
    Instruction: pcmpgtd mm, mm

    MMX 
    a < b
    __m64 _mm_cmpgt_pi32 (__m64 b, __m64 a)
    #include <mmintrin.h>
    Instruction: pcmpgtd mm, mm

in_rect()
  w = rect.x + rect.w
  h = rect.y + rect.h
  rect.x <= x && x < w
  rect.y <= y && y < rect.h


