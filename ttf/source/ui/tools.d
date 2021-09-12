module ui.ttf.tools;

import std.range;
import std.stdio;
import std.format;
import std.bitmanip;
import ui.ttf.types;


string bitFieldToString( ENUM, T )( T a )
{
    import std.algorithm.iteration : joiner;
    import std.traits;

    string[] ss;
    
    if ( a == 0 )
    {
        return "(none)";
    }
    else
    {
        static 
        foreach ( member; EnumMembers!ENUM )
        {
            if ( ( a & member ) != 0 )
                ss ~= member.stringof;
        }

        return ss.join( " | " );
    }
}


string flagsToString( uint16 a )
{
    return bitFieldToString!HeadFlags( a );
}


string macStyleToString( uint16 a )
{
    return bitFieldToString!MacStyle( a );
}


string fontDirectionHintToString( int16 a )
{
    return 
        format!"%s"
        ( 
            ( cast( FontDirectionHint ) a )
        );
}

auto scalerTypeString( in uint32 scalerType )
{
    // "true"
    if ( scalerType == Tag!"true" || scalerType == Tag!0x00_01_00_00 ) 
        return "ttf";
    else

    // "typ1"
    if ( scalerType == Tag!"typ1" )
        return "typ1"; // old style PostScript font
    else

    // "OTTO"
    if ( scalerType == Tag!"OTTO" )
        return "OTTO"; // OpenType font with PostScript outlines
    else

        return "not ttf";
}


// "true" -> 0x74_72_75_65
template Tag( char[4] s )
{
    version ( LittleEndian )
    {
        const enum Tag = littleEndianToNative!uint32( cast( ubyte[4]) s );
    }
    else
    {
        const enum Tag = bigEndianToNative!uint32( cast( ubyte[4]) s );
    }
}

// 0x74_72_75_65 -> 0x74_72_75_65
template Tag( uint32 x )
{
    version ( LittleEndian )
    {
        enum Tag = x.swapEndian;
    }
    else
    {
        enum Tag = x;
    }
}


string tagName( uint32 x )
{
    ubyte[4] cccc = nativeToLittleEndian( x );

    return 
        format!"%c%c%c%c"
        ( 
            cast( char ) cccc[0],
            cast( char ) cccc[1],
            cast( char ) cccc[2],
            cast( char ) cccc[3],
        );
}


auto between( T )( in T a, in T b, in Tc )
{
    return ( a >= b ) && ( a <= c );
}
