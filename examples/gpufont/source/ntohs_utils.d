module ntohs_utils;

import core.stdc.stdint;
import std.bitmanip;


uint16_t htons( uint16_t x )
{
    version( BigEndian )
    {
        return x;
    }
    else version( LittleEndian ) // all x86 systems
    {
        //return __bswap_16( x );
        return x.swapEndian;
    }
    else
    {
        pragma( msg, "What kind of system is this?" );
        assert( 0, "What kind of system is this?" );
    }
}
alias ntohs = htons;


uint32_t htonl( uint32_t x )
{
    version( BigEndian )
    {
        return x;
    }
    else version( LittleEndian ) // all x86 systems
    {
        //return __bswap_32( x );
        return x.swapEndian;
    }
    else
    {
        pragma( msg, "What kind of system is this?" );
        assert( 0, "What kind of system is this?" );
    }
}
alias ntohl = htonl;


uint16_t __bswap_16( uint16_t x )
{
    return ( ( x >> 8 ) & 0xff ) | ( ( x & 0xff ) << 8 );
}

uint32_t __bswap_32( uint32_t x )
{
    return 
      ( ( x & 0xff000000 ) >> 24 ) | ( ( x & 0x00ff0000 ) >>  8 ) |
      ( ( x & 0x0000ff00 ) <<  8 ) | ( ( x & 0x000000ff ) << 24 );
}

 unittest
{
    assert( htonl( 0x67452301 ) == 0x01234567 );
    assert( ntohl( 0x67452301 ) == 0x01234567 );
    assert( htons( 0x1234 ) == 0x3412 );
    assert( ntohs( 0x1234 ) == 0x3412 );
}
