module ui.ttf.types;

import std.range;
import std.stdio;
import std.format;
import std.bitmanip;
import ui.ttf.tools;


// types
alias shortFrac    = short; //  A shortFrac is an int16_t with a bias of 14. This means it can represent numbers between 1.999 (0x7fff) and -2.0 (0x8000). 1.0 is stored as 16384 (0x4000) and -1.0 is stored as -16384 (0xc000).
struct Fixed
{
    int a;
    alias a this;

    // from float
    this( float a ) 
    {
        this.a = cast( int )( a * 65536 );
    }

    /**
    * Convert a 16.16 fixed-point value to floating point
    * @param val The fixed-point value
    * @return The equivalent floating-point value.
    */
    float toFloat()
    {
        return ( cast( float ) a ) / 65536.0f;
    }

    auto swapEndian()
    {
        return std.bitmanip.swapEndian( a );
    }
}

struct FWord
{
    short a;
    alias a this;

    auto swapEndian()
    {
        return std.bitmanip.swapEndian( a );
    }
}

alias uFWord       = ushort;
alias F2Dot14      = short;

struct longDateTime 
{
    // The long internal format of a date in seconds since 12:00 midnight, January 1, 1904. It is represented as a signed 64-bit integer.
    uint[2] uint_;
    alias uint_ this;

    string toString()
    {
        // date in seconds since 12:00 midnight, January 1, 1904
        import std.datetime;
        import std.datetime.date;

        auto dt = DateTime( 1904, 1, 1, 12, 0, 0 ) + a.seconds;

        return dt.toISOExtString();
    }

    ulong a()
    {
        return uint_[0] * 0x0001_0000 + uint_[1];
    }

    uint[2] swapEndian()
    {
        return 
            [ 
                std.bitmanip.swapEndian( uint_[0] ),
                std.bitmanip.swapEndian( uint_[1] )
            ];
    }
}

alias uint8  = ubyte;
alias int16  = short;
alias uint24 = ubyte[3];
alias uint32 = uint;
alias UInt8  = ubyte;
alias uint16 = ushort;
alias UInt16 = ushort;
alias UInt32 = uint;
alias BYTE   = ubyte;

struct Header
{
    OffsetTable offsetTable;
}

// The offset subtable
struct OffsetTable
{
    uint32 scalerType;    // A tag to indicate the OFA scaler to be used to rasterize this font; see the note on the scaler type below for more information.
    uint16 numTables;     // number of tables
    uint16 searchRange;   // (maximum power of 2 <= numTables)*16
    uint16 entrySelector; // log2(maximum power of 2 <= numTables)
    uint16 rangeShift;    // numTables*16-searchRange
}

// The table directory
struct TableDirectoryRec
{
    uint32 tag;      // 4-byte identifier
    uint32 checkSum; // checksum for this table
    uint32 offset;   // offset from beginning of sfnt
    uint32 length;   // length of this table in byte (actual length not padded length)
}


// Glyph
// Glyph description
struct GlyphDescription
{
    int16 numberOfContours; // If the number of contours is positive or zero, it is a single glyph;
                            // If the number of contours less than zero, the glyph is compound
    FWord xMin;             // Minimum x for coordinate data
    FWord yMin;             // Minimum y for coordinate data
    FWord xMax;             // Maximum x for coordinate data
    FWord yMax;             // Maximum y for coordinate data
                            // (here follow the data for the simple or compound glyph)
}

// Simple glyph definition
struct SimpleGlyphDefinition
{
    enum N                 = 0;
    enum INSTRUCTIONLENGTH = 0;
    enum VARIABLE          = 0;

    uint16[N]                endPtsOfContours;  // Array of last points of each contour; n is the number of contours; array entries are point indices
    uint16                   instructionLength; // Total number of bytes needed for instructions
    uint8[INSTRUCTIONLENGTH] instructions;      // Array of instructions for this glyph
    uint8[VARIABLE]          flags;             // Array of flags
    int16[0]                 xCoordinates;      // Array of x-coordinates; the first is relative to (0,0), others are relative to previous point
    int16[0]                 yCoordinates;      // Array of y-coordinates; the first is relative to (0,0), others are relative to previous point
    //uint8[]                  xCoordinates;      // Array of x-coordinates; the first is relative to (0,0), others are relative to previous point
    //uint8[]                  yCoordinates;      // Array of y-coordinates; the first is relative to (0,0), others are relative to previous point
}

enum OutlineFlags : uint8
{
    OnCurve      = 0b0000_0001,  // If set, the point is on the curve;
                                 // Otherwise, it is off the curve.
    xShortVector = 0b0000_0010,  // If set, the corresponding x-coordinate is 1 byte long;
                                 // Otherwise, the corresponding x-coordinate is 2 bytes long
    yShortVector = 0b0000_0100,  // If set, the corresponding y-coordinate is 1 byte long;
                                 // Otherwise, the corresponding y-coordinate is 2 bytes long
    Repeat       = 0b0000_1000,  // If set, the next byte specifies the number of additional times this set of flags is to be repeated. In this way, the number of flags listed can be smaller than the number of points in a character.
    ThisXisSame  = 0b0001_0000,  // (Positive x-Short vector) // This flag has one of two meanings, depending on how the x-Short Vector flag is set.
                                 // If the x-Short Vector bit is set, this bit describes the sign of the value, with a value of 1 equalling positive and a zero value negative.
                                 // If the x-short Vector bit is not set, and this bit is set, then the current x-coordinate is the same as the previous x-coordinate.
                                 // If the x-short Vector bit is not set, and this bit is not set, the current x-coordinate is a signed 16-bit delta vector. In this case, the delta vector is the change in x
    ThisYisSame  = 0b0010_0000,  // (Positive y-Short vector) // This flag has one of two meanings, depending on how the y-Short Vector flag is set.
                                 // If the y-Short Vector bit is set, this bit describes the sign of the value, with a value of 1 equalling positive and a zero value negative.
                                 // If the y-short Vector bit is not set, and this bit is set, then the current y-coordinate is the same as the previous y-coordinate.
                                 // If the y-short Vector bit is not set, and this bit is not set, the current y-coordinate is a signed 16-bit delta vector. In this case, the delta vector is the change in y
    Reserved     = 0b0100_0000,  // Set to zero
    Reserved2    = 0b1000_0000   // Set to zero
}

// Compound glyphs
// Component glyph part description
struct ComponentGlyphPartDescription
{
    uint16  flags;       // Component flag
    uint16  glyphIndex;  // Glyph index of component
    uint8   argument1;   // X-offset for component or point number; type depends on bits 0 and 1 in component flags
    uint8   argument2;   // Y-offset for component or point number type depends on bits 0 and 1 in component flags
                         // transformation option   One of the transformation options from Table 19
    // int8   argument1;
    // int8   argument2;
    // uint16 argument1;
    // uint16 argument2;
    // int16  argument1;
    // int16  argument2;
}

enum ComponentFlags
{
    ARG_1_AND_2_ARE_WORDS    = 0b0000_0000_0001, // If set, the arguments are words;
                                                 // If not set, they are bytes.
    ARGS_ARE_XY_VALUES       = 0b0000_0000_0010, // If set, the arguments are xy values;
                                                 // If not set, they are points.
    ROUND_XY_TO_GRID         = 0b0000_0000_0100, // If set, round the xy values to grid;
                                                 // if not set do not round xy values to grid (relevant only to bit 1 is set)
    WE_HAVE_A_SCALE          = 0b0000_0000_1000, // If set, there is a simple scale for the component.
                                                 // If not set, scale is 1.0.
    OBSOLETE                 = 0b0000_0001_0000, // (this bit is obsolete)  4   (obsolete; set to zero)
    MORE_COMPONENTS          = 0b0000_0010_0000, // If set, at least one additional glyph follows this one.
    WE_HAVE_AN_X_AND_Y_SCALE = 0b0000_0100_0000, // If set the x direction will use a different scale than the y direction.
    WE_HAVE_A_TWO_BY_TWO     = 0b0000_1000_0000, // If set there is a 2-by-2 transformation that will be used to scale the component.
    WE_HAVE_INSTRUCTIONS     = 0b0001_0000_0000, // If set, instructions for the component character follow the last component.
    USE_MY_METRICS           = 0b0010_0000_0000, // Use metrics from this component for the compound glyph.
    OVERLAP_COMPOUND         = 0b0100_0000_0000  // If set, the components of this compound glyph overlap.
}


// cmap
struct CmapTable
{
    UInt16 version_;        // Version number (Set to zero)
    UInt16 numberSubtables; // Number of encoding subtables
}

struct CmapSubTable
{
    UInt16 platformID;          //  Platform identifier
    UInt16 platformSpecificID;  //  Platform-specific encoding identifier
    UInt32 offset;              //  Offset of the mapping table
}

enum CmapPlatformID : UInt16
{
    Unicode   = 0, // Indicates Unicode version.
    Macintosh = 1, // Script Manager code.
    reserved  = 2, // ; do not use)
    Microsoft = 3, // Microsoft encoding.
}

enum CmapUnicodePlatformSpecificID : UInt16
{
    Version_1_0                 = 0, // Version 1.0 semantics
    Version_1_1                 = 1, // Version 1.1 semantics
    ISO_10646_1993              = 2, // ISO 10646 1993 semantics (deprecated)
    Unicode_2_0_BMP_only        = 3, // Unicode 2.0 or later semantics (BMP only)
    Unicode_2_0_non_BMP         = 4, // Unicode 2.0 or later semantics (non-BMP characters allowed)
    Unicode_Variation_Sequences = 5, // Unicode Variation Sequences
    Last_Resort                 = 6, // Last Resort
}

enum CmapWindowsPlatformSpecificID : UInt16
{
    Symbol                 = 0,
    Unicode_BMP_only_UCS_2 = 1,
    Shift_JIS              = 2,
    PRC                    = 3,
    BigFive                = 4,
    Johab                  = 5,
    Unicode_UCS_4          = 10,
}

struct CmapFormat0
{
    UInt16     format;          // Set to 0
    UInt16     length;          // Length in bytes of the subtable (set to 262 for format 0)
    UInt16     language;        // Language code (see above)
    UInt8[256] glyphIndexArray; // An array that maps character codes to glyph index values
}

struct CmapFormat2
{
    enum VARIABLE = 0;

    UInt16              format;          // Set to 2
    UInt16              length;          // Total table length in bytes
    UInt16              language;        // Language code (see above)
    UInt16[256]         subHeaderKeys;   // Array that maps high bytes to subHeaders: value is index * 8
    UInt16[4][VARIABLE] subHeaders;      // Variable length array of subHeader structures
    UInt16[VARIABLE]    glyphIndexArray; // Variable length array containing subarrays
}

struct CmapFormat4
{
    enum SEGCOUNT = 0;
    enum VARIABLE = 0;

    UInt16            format;          // Format number is set to 4
    UInt16            length;          // Length of subtable in bytes
    UInt16            language;        // Language code (see above)          
    UInt16            segCountX2;      // 2 * segCount          
    UInt16            searchRange;     // 2 * (2**FLOOR(log2(segCount)))
    UInt16            entrySelector;   // log2(searchRange/2)          
    UInt16            rangeShift;      // (2 * segCount) - searchRange
    //ubyte[]           arrays;
    //UInt16[SEGCOUNT]  endCode;         // Ending character code for each segment, last = 0xFFFF.
    //UInt16            reservedPad;     // This value should be zero
    //UInt16[SEGCOUNT]  startCode;       // Starting character code for each segment
    //UInt16[SEGCOUNT]  idDelta;         // Delta for all character codes in segment
    //UInt16[SEGCOUNT]  idRangeOffset;   // Offset in bytes to glyph indexArray, or 0
    //UInt16[VARIABLE]  glyphIndexArray; // Glyph index array
    UInt16[]          endCode;         // Ending character code for each segment, last = 0xFFFF.
    UInt16            reservedPad;     // This value should be zero
    UInt16[]          startCode;       // Starting character code for each segment
    UInt16[]          idDelta;         // Delta for all character codes in segment
    UInt16[]          idRangeOffset;   // Offset in bytes to glyph indexArray, or 0
    UInt16[]          glyphIndexArray; // Glyph index array
}

struct CmapFormat4Short
{
    UInt16            format;          // Format number is set to 4          
    UInt16            length;          // Length of subtable in bytes
    UInt16            language;        // Language code (see above)          
    UInt16            segCountX2;      // 2 * segCount          
    UInt16            searchRange;     // 2 * (2**FLOOR(log2(segCount)))
    UInt16            entrySelector;   // log2(searchRange/2)          
    UInt16            rangeShift;      // (2 * segCount) - searchRange
}

struct CmapFormat6
{
    enum ENTRYCOUNT = 0;

    UInt16             format;          // Subtable format; set to 6
    UInt16             length;          // Byte length of this subtable (including the header)
    UInt16             language;        // Language code (see above)
    UInt16             firstCode;       // First character code of subrange
    UInt16             entryCount;      // Number of character codes in subrange
    UInt16[ENTRYCOUNT] glyphIndexArray; // Array of glyph index values for character codes in the range
}

struct CmapFormat8
{
    UInt16                 format;   // Subtable format; set to 8
    UInt16                 reserved; // Set to 0
    UInt32                 length;   // Byte length of this subtable (including the header)
    UInt32                 language; // Language code (see above)
    UInt8[65536]           is32;     // Tightly packed array of bits (8K bytes total) indicating whether the particular 16-bit (index) value is the start of a 32-bit character code
    UInt32                 nGroups;  // Number of groupings which follow    
    CmapFormat8GroupRec[0] groups;
}

struct CmapFormat10
{
    UInt16    format;        // Subtable format; set to 10
    UInt16    reserved;      // Set to 0
    UInt32    length;        // Byte length of this subtable (including the header)
    UInt32    language;      // Language code (see above)
    UInt32    startCharCode; // First character code covered
    UInt32    numChars;      // Number of character codes covered
    UInt32    nGroups;       // Number of groupings which follow    
    UInt16[0] glyphs;        // Array of glyph indices for the character codes covered
}

struct CmapFormat12
{
    UInt16                 format;   // Subtable format; set to 12
    UInt16                 reserved; // Set to 0
    UInt32                 length;   // Byte length of this subtable (including the header)
    UInt32                 language; // Language code (see above)
    UInt32                 nGroups;  // Number of groupings which follow    
    CmapFormat8GroupRec[0] groups;
}

struct CmapFormat13
{
    UInt16                 format;   // Subtable format; set to 13
    UInt16                 reserved; // Set to 0
    UInt32                 length;   // Byte length of this subtable (including the header)
    UInt32                 language; // Language code (see above)
    UInt32                 nGroups;  // Number of groupings which follow    
    CmapFormat8GroupRec[0] groups;
}

struct CmapFormat14
{
    UInt16                  format;                // Subtable format; set to 14
    UInt32                  length;                // Byte length of this subtable (including the header)
    UInt32                  numVarSelectorRecords; // Number of variation Selector Records
    VariationSelectorRec[0] records;               // This is immediately followed by ‘numVarSelectorRecords’ Variation Selector Records.
}

struct VariationSelectorRec
{
    uint24 varSelector;         // Variation selector
    uint32 defaultUVSOffset;    // Offset to Default UVS Table. May be 0.
    uint32 nonDefaultUVSOffset; // Offset to Non-Default UVS Table. May be 0.
}

struct UVSTable
{
    uint32 numUnicodeValueRanges; // Number of ranges that follow
}

struct UVRange
{
    uint24 startUnicodeValue; // First value in this range
    BYTE   additionalCount;   // Number of additional values in this range
}

struct UVSTableNonDefault
{
    uint32 numUVSMappings; // Number of UVS Mappings that follow
}

struct UVSMapping
{
    uint24 unicodeValue; // Base Unicode value of the UVS
    uint16 glyphID;      // Glyph ID of the UVS    
}

struct CmapMappingTable
{
    union
    {
        UInt16       format;
        CmapFormat0  format0;
        CmapFormat2  format2;
        CmapFormat4  format4;
        CmapFormat6  format6;
        CmapFormat8  format8;
        CmapFormat10 format10;
        CmapFormat12 format12;
        CmapFormat13 format13;
        CmapFormat14 format14;
    }
}

struct CmapFormat8GroupRec
{
    UInt32 startCharCode;   // First character code in this group; note that if this group is for one or more 16-bit character codes (which is determined from the is32 array), this 32-bit value will have the high 16-bits set to zero
    UInt32 endCharCode;     // Last character code in this group; same condition as listed above for the startCharCode
    UInt32 startGlyphCode;  // Glyph index corresponding to the starting character code    
}


struct HeadTable
{
    Fixed   version_;            // 0x00010000 if (version 1.0)
    Fixed   fontRevision;        // set by font manufacturer
    uint32  checkSumAdjustment;  // To compute: set it to 0, calculate the checksum for the 'head' table and put it in the table directory, sum the entire font as a uint32_t, then store 0xB1B0AFBA - sum. (The checksum for the 'head' table will be wrong as a result. That is OK; do not reset it.)
    uint32  magicNumber;         // set to 0x5F0F3CF5
    uint16  flags;               // bit 0 - y value of 0 specifies baseline
                                 // bit 1 - x position of left most black bit is LSB
                                 // bit 2 - scaled point size and actual point size will differ (i.e. 24 point glyph differs from 12 point glyph scaled by factor of 2)
                                 // bit 3 - use integer scaling instead of fractional
                                 // bit 4 - (used by the Microsoft implementation of the TrueType scaler)
                                 // bit 5 - This bit should be set in fonts that are intended to e laid out vertically, and in which the glyphs have been drawn such that an x-coordinate of 0 corresponds to the desired vertical baseline.
                                 // bit 6 - This bit must be set to zero.
                                 // bit 7 - This bit should be set if the font requires layout for correct linguistic rendering (e.g. Arabic fonts).
                                 // bit 8 - This bit should be set for an AAT font which has one or more metamorphosis effects designated as happening by default.
                                 // bit 9 - This bit should be set if the font contains any strong right-to-left glyphs.
                                 // bit 10 - This bit should be set if the font contains Indic-style rearrangement effects.
                                 // bits 11-13 - Defined by Adobe.
                                 // bit 14 - This bit should be set if the glyphs in the font are simply generic symbols for code point ranges, such as for a last resort font.
    uint16  unitsPerEm;          // range from 64 to 16384
    longDateTime created;        // international date
    longDateTime modified;       // international date
    FWord   xMin;                // for all glyph bounding boxes
    FWord   yMin;                // for all glyph bounding boxes
    FWord   xMax;                // for all glyph bounding boxes
    FWord   yMax;                // for all glyph bounding boxes
    uint16  macStyle;            // bit 0 bold
                                 // bit 1 italic
                                 // bit 2 underline
                                 // bit 3 outline
                                 // bit 4 shadow
                                 // bit 5 condensed (narrow)
                                 // bit 6 extended
    uint16  lowestRecPPEM;       // smallest readable size in pixels
    int16   fontDirectionHint;   // 0 Mixed directional glyphs
                                 // 1 Only strongly left to right glyphs
                                 // 2 Like 1 but also contains neutrals
                                 // -1 Only strongly right to left glyphs
                                 // -2 Like -1 but also contains neutrals
    int16   indexToLocFormat;    // 0 for short offsets, 1 for long
    int16   glyphDataFormat;     // 0 for current format
}

enum FontDirectionHint : int16
{
    mixed = 0,
    left_to_right =  1,
    right_to_left = -1,
    left_to_right_and_neutral =  2,
    right_to_left_and_neutral = -2,
}

enum MacStyle : uint16
{
    bold      = 0b0000_0001, // bit 0 bold
    italic    = 0b0000_0010, // bit 1 italic
    underline = 0b0000_0100, // bit 2 underline
    outline   = 0b0000_1000, // bit 3 outline
    shadow    = 0b0001_0000, // bit 4 shadow
    condensed = 0b0010_0000, // bit 5 condensed (narrow)
    extended  = 0b0100_0000, // bit 6 extended
}


enum HeadFlags : uint16
{
    y_value_of_0_specifies_baseline                     = 0b0000_0000_0000_0001, // bit 0 - y value of 0 specifies baseline
    x_position_of_left_most_black_bit_is_LSB            = 0b0000_0000_0000_0010, // bit 1 - x position of left most black bit is LSB
    scaled_point_size_and_actual_point_size_will_differ = 0b0000_0000_0000_0100, // bit 2 - scaled point size and actual point size will differ (i.e. 24 point glyph differs from 12 point glyph scaled by factor of 2)
    use_integer_scaling                                 = 0b0000_0000_0000_1000, // bit 3 - use integer scaling instead of fractional
    Microsoft_implementation                            = 0b0000_0000_0001_0000, // bit 4 - (used by the Microsoft implementation of the TrueType scaler)
    intended_to_e_laid_out_vertically                   = 0b0000_0000_0010_0000, // bit 5 - This bit should be set in fonts that are intended to e laid out vertically, and in which the glyphs have been drawn such that an x-coordinate of 0 corresponds to the desired vertical baseline.
    zero                                                = 0b0000_0000_0100_0000, // bit 6 - This bit must be set to zero.
    requires_layout_for_correct_linguistic_rendering    = 0b0000_0000_1000_0000, // bit 7 - This bit should be set if the font requires layout for correct linguistic rendering (e.g. Arabic fonts).
    has_metamorphosis_effectsby_default                 = 0b0000_0001_0000_0000, // bit 8 - This bit should be set for an AAT font which has one or more metamorphosis effects designated as happening by default.
    contains_any_strong_right_to_left_glyphs            = 0b0000_0010_0000_0000, // bit 9 - This bit should be set if the font contains any strong right-to-left glyphs.
    contains_Indic_style_rearrangement_effects          = 0b0000_0100_0000_0000, // bit 10 - This bit should be set if the font contains Indic-style rearrangement effects.
    adobe11                                             = 0b0000_1000_0000_0000, // bits 11-13 - Defined by Adobe.
    adobe12                                             = 0b0001_0000_0000_0000, // bits 11-13 - Defined by Adobe.
    adobe13                                             = 0b0010_0000_0000_0000, // bits 11-13 - Defined by Adobe.
    glyphs_in_the_font_are_simply_generic_symbols       = 0b0100_0000_0000_0000, // bit 14 - This bit should be set if the glyphs in the font are simply generic symbols for code point ranges, such as for a last resort font.
}

struct LocaTableShort
{
    uint16[] offsets;
}

struct LocaTableLong
{
    uint32[] offsets;
}


struct LocaTable
{
    union
    {
        LocaTableShort short_;
        LocaTableLong  long_;
    }
}


struct MaxpTable
{
    Fixed  version_;              // 0x00010000 (1.0)
    uint16 numGlyphs;             // the number of glyphs in the font
    uint16 maxPoints;             // points in non-compound glyph
    uint16 maxContours;           // contours in non-compound glyph
    uint16 maxComponentPoints;    // points in compound glyph
    uint16 maxComponentContours;  // contours in compound glyph
    uint16 maxZones;              // set to 2
    uint16 maxTwilightPoints;     // points used in Twilight Zone (Z0)
    uint16 maxStorage;            // number of Storage Area locations
    uint16 maxFunctionDefs;       // number of FDEFs
    uint16 maxInstructionDefs;    // number of IDEFs
    uint16 maxStackElements;      // maximum stack depth
    uint16 maxSizeOfInstructions; // byte count for glyph instructions
    uint16 maxComponentElements;  // number of glyphs referenced at top level
    uint16 maxComponentDepth;     // levels of recursion, set to 0 if font has only simple glyphs
}


struct MaxpTableOpenType
{
    Fixed  version_;              // 0x00010000 (1.0)
    uint16 numGlyphs;             // the number of glyphs in the font
}


struct HheaTable
{
    Fixed  version_;            // 0x00010000 (1.0)
    FWord  ascent;              // Distance from baseline of highest ascender
    FWord  descent;             // Distance from baseline of lowest descender
    FWord  lineGap;             // typographic line gap
    uFWord advanceWidthMax;     // must be consistent with horizontal metrics
    FWord  minLeftSideBearing;  // must be consistent with horizontal metrics
    FWord  minRightSideBearing; // must be consistent with horizontal metrics
    FWord  xMaxExtent;          // max(lsb + (xMax-xMin))
    int16  caretSlopeRise;      // used to calculate the slope of the caret (rise/run) set to 1 for vertical caret
    int16  caretSlopeRun;       // 0 for vertical
    FWord  caretOffset;         // set value to 0 for non-slanted fonts
    int16  reserved;            // set value to 0
    int16  reserved2;           // set value to 0
    int16  reserved3;           // set value to 0
    int16  reserved4;           // set value to 0
    int16  metricDataFormat;    // 0 for current format
    uint16 numOfLongHorMetrics; // number of advance widths in metrics table    
}


struct LongHorMetric
{
    uint16 advanceWidth;
    int16  leftSideBearing;
}


struct HmtxTable
{
    // hhea.numOfLongHorMetrics elements
    LongHorMetric[] hMetrics;        // The value numOfLongHorMetrics comes from the 'hhea' table. If the font is monospaced, only one entry need be in the array but that entry is required.
    FWord[]         leftSideBearing; // Here the advanceWidth is assumed to be the same as the advanceWidth for the last entry above. The number of entries in this array is derived from the total number of glyphs minus numOfLongHorMetrics. This generally is used with a run of monospaced glyphs (e.g. Kanji fonts or Courier fonts). Only one run is allowed and it must be at the end.
}


struct NameTable
{
    UInt16       format;       // Format selector. Set to 0.
    UInt16       count;        // The number of nameRecords in this name table.
    UInt16       stringOffset; // Offset in bytes to the beginning of the name character strings.
    NameRecord[] nameRecord;   // The name records array.
    //variable     name;         // Character strings. The character strings of the names. Note that these are not necessarily ASCII!
}


struct NameTableShort
{
    UInt16       format;       // Format selector. Set to 0.
    UInt16       count;        // The number of nameRecords in this name table.
    UInt16       stringOffset; // Offset in bytes to the beginning of the name character strings.
}


struct NameRecord
{
    UInt16 platformID;         // Platform identifier code.
    UInt16 platformSpecificID; // Platform-specific encoding identifier.
    UInt16 languageID;         // Language identifier.
    UInt16 nameID;             // Name identifier.
    UInt16 length;             // Name string length in bytes.
    UInt16 offset;             // Name string offset in bytes from stringOffset.
}


enum PlatformIdentifier
{
    Unicode   = 0, // Indicates Unicode version.
    Macintosh = 1, // QuickDraw Script Manager code.
    reserved  = 2, // (reserved; do not use)
    Microsoft = 3, // Microsoft encoding.
}

