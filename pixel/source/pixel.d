module ui.pixel;

import std;


// For 32k display 
//   32bit = 16bit + 16bit
//   Integer + Fragment:
//     ( -32767 .. 32767 ) + ( 0/65536 .. 65536/65536 ) 
//     -( 2^15 << 16 + 2^16 ) .. +( 2^15 << 16 + 2^16 )
version ( LittleEndian ) 
struct IntFr
{
    union 
    {
        int a;
        struct 
        {
            ushort fr;
            short  n;
        }
    }
    alias a this;
}

version ( BigEndian ) 
struct IntFr
{
    union 
    {
        int a;
        struct 
        {
            short  n;
            ushort fr;
        }
    }
    alias a this;
}


// 64bit = 32bit + 32bit
struct Pixel
{
    IntFr x;
    IntFr y;
}


void main()
{
    IntFr a;
    a.n  = 1;
    a.fr = 0;
    writeln( a.a );
    writeln( a.n );
    writeln( a.fr );
}


