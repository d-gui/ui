//module ui.ttf;

import std.range;
import std.stdio;
import std.format;
import std.bitmanip;
import ui.ttf.types;
import ui.ttf.tools;


void main(  )
{
    string fileName = "data/DejaVuSans.ttf";
    TTF( fileName ).readFile();
}

struct TTF
{
    string               fileName;
    Header[1]            header;
    HeadTable[1]         headTable;
    MaxpTable[1]         maxpTable;
    LocaTable[]          locaTable;
    HheaTable[1]         hheaTable;
    HmtxTable[1]         hmtxTable;
    NameTable[1]         nameTable;
    TableDirectoryRec[]  tableRecs;


    void readFile()
    {
        auto f = File( fileName );
        readFileHeader( f );
        readTableRecords( f );
        readEachTable( f );
    }


    void readFileHeader( ref File f )
    {
        f.rawRead( header );

        with ( header.ptr.offsetTable )
        {
            version ( LittleEndian ) 
            {
                numTables     = numTables.swapEndian;
                searchRange   = searchRange.swapEndian;
                entrySelector = entrySelector.swapEndian;
                rangeShift    = rangeShift.swapEndian;
            }

            writefln( "File Header:" );
            writefln( "  scalerType    : 0x%x: %s", scalerType, scalerTypeString( scalerType ) );
            writefln( "  numTables     : %d",   numTables );
            writefln( "  searchRange   : 0x%x", searchRange );
            writefln( "  entrySelector : 0x%x", entrySelector );
            writefln( "  rangeShift    : 0x%x", rangeShift );
        }
    }


    void readTableRecords( ref File f )
    {
        // Read Table Records
        if ( header.ptr.offsetTable.numTables > 0 )
        {        
            tableRecs.length = header.ptr.offsetTable.numTables;

            tableRecs = f.rawRead( tableRecs );
        }
    }


    void readEachTable( ref File f )
    {
        uint32 locaOffset;
        uint32 hmtxOffset;

        foreach ( ref tableRec; tableRecs )
        {
            with ( tableRec )
            {
                version ( LittleEndian ) 
                {
                    checkSum = checkSum.swapEndian;
                    offset   = offset.swapEndian;
                    length   = length.swapEndian;
                }

                writefln( "rec %s:", tagName( tag ) );
                writefln( "  tag      : %s",   tagName( tag ) );
                writefln( "  checkSum : 0x%x", checkSum );
                writefln( "  offset   : 0x%x", offset );
                writefln( "  length   : %d",   length );

                switch ( tag )
                {
                    case Tag!"glyf":
                        readGpyfTable( f, offset );
                        break;

                    case Tag!"cmap":
                        readCmapTable( f, offset );
                        break;

                    case Tag!"head":
                        readHeadTable( f, offset );
                        break;

                    case Tag!"loca":
                        // read after maxo, head loaded
                        locaOffset = offset;
                        break;

                    case Tag!"maxp":
                        readMaxpTable( f, offset );
                        break;

                    case Tag!"hhea":
                        readHheaTable( f, offset );
                        break;

                    case Tag!"hmtx":
                        // after hhea, maxp
                        hmtxOffset = offset;
                        break;

                    case Tag!"name":
                        readNameTable( f, offset );
                        break;

                    default:
                }
            }
        }

        // depend from maxp, head
        if ( locaOffset )
            readLocaTable( f, locaOffset );

        // depend from hhea, maxp
        if ( hmtxOffset )
            readHmtxTable( f, hmtxOffset );

        // depend from loca, glyf
        ushort charCode = 'A';
        //findGlyfFormat4( charCode, selectedCmapTable.format4, locaTable );
    }


    void readGpyfTable( ref File f, uint32 offset )
    {
        GlyphDescription[1] glyphDescription;

        f.seek( offset );
        f.rawRead( glyphDescription );

        with ( glyphDescription.ptr )
        {
            version ( LittleEndian ) 
            {
                numberOfContours = numberOfContours.swapEndian;
            }

            writeln( "  gpyf: " );
            writeln( "    numberOfContours : ", numberOfContours );
        }
    }


    void readCmapTable( ref File f, uint32 offset )
    {
        CmapTable[1] cmapTable;

        f.seek( offset );
        f.rawRead( cmapTable );

        with ( cmapTable.ptr )
        {
            version ( LittleEndian ) 
            {
                version_        = version_.swapEndian;
                numberSubtables = numberSubtables.swapEndian;
            }

            writefln( "  cmap:" );
            writefln( "    version         : 0x%x", version_ );
            writefln( "    numberSubtables : %d",   numberSubtables );
        }

        // Records
        if ( cmapTable.ptr.numberSubtables > 0 )
        {
            CmapSubTable[] cmapSubTables;
            cmapSubTables.length = cmapTable.ptr.numberSubtables;

            cmapSubTables = f.rawRead( cmapSubTables );

            foreach ( ref cmapSubTable; cmapSubTables )
            {
                with ( cmapSubTable )
                {
                    version ( LittleEndian ) 
                    {
                        platformID          = platformID.swapEndian;
                        platformSpecificID  = platformSpecificID.swapEndian;
                        cmapSubTable.offset = cmapSubTable.offset.swapEndian;
                    }

                    writefln(         "    rec:" );
                    writefln(         "      platformID         : %s",   cast( CmapPlatformID ) platformID );
                    switch ( platformID )
                    {
                        case CmapPlatformID.Unicode:
                            writefln( "      platformSpecificID : %s", cast( CmapUnicodePlatformSpecificID ) platformSpecificID );
                            break;
                        case CmapPlatformID.Microsoft:
                            writefln( "      platformSpecificID : %s", cast( CmapWindowsPlatformSpecificID ) platformSpecificID );
                            break;
                        default:
                            writefln( "      platformSpecificID : %s", platformSpecificID );
                    }
                    writefln(         "      offset             : 0x%08x", cmapSubTable.offset );
                }

                readCmapMappingTable( f, offset + cmapSubTable.offset );
            }

            // cmaps
            //readCmapMappingTable( f, offset + cmapSubTables[0].offset );
        }
    }


    void readCmapMappingTable( ref File f, uint32 offset )
    {
        CmapMappingTable[1] cmapMappingTable;

        f.seek( offset );
        f.rawRead( ( &cmapMappingTable[0].format )[ 0 .. 1 ] );

        with ( cmapMappingTable[0] )
        {
            version ( LittleEndian ) 
            {
                format = format.swapEndian;
            }
        }

        // format 0
        // format 2
        // format 4
        switch ( cmapMappingTable[0].format )
        {
            //case  0: loadCmapTableFormat0(  cmapMappingTable[0].format0 ); break;
            //case  2: loadCmapTableFormat2(  cmapMappingTable[0].format2 ); break;
            case  4: loadCmapTableFormat4(  f, offset, cmapMappingTable[0].format4 ); break;
            //case  6: loadCmapTableFormat6(  cmapMappingTable[0].format6 ); break;
            //case  8: loadCmapTableFormat8(  cmapMappingTable[0].format8 ); break;
            //case 10: loadCmapTableFormat10( cmapMappingTable[0].format10 ); break;
            //case 12: loadCmapTableFormat12( cmapMappingTable[0].format12 ); break;
            //case 13: loadCmapTableFormat13( cmapMappingTable[0].format13 ); break;
            //case 14: loadCmapTableFormat14( cmapMappingTable[0].format14 ); break;
            default:
                with ( cmapMappingTable[0] )
                    writefln( "      format : 0x%x: %d", format, format );
        }
    }


    void loadCmapTableFormat0( ref CmapFormat0 table )
    {
        with ( table )
        {            
            version ( LittleEndian ) 
            {
                //format   = format.swapEndian; // swapped before
                length   = length.swapEndian;
                language = language.swapEndian;
            }

            writeln(  "      cmap:" );
            writefln( "        format   : 0x%x: %d", format, format );
            writefln( "        length   : 0x%x: %d", length, length );
            writefln( "        language : 0x%x: %d", language, language );
        }        
    }


    void loadCmapTableFormat2( ref CmapFormat2 table )
    {
        with ( table )
        {            
            version ( LittleEndian )
            {
                //format        = format.swapEndian; // swapped before
                length        = length.swapEndian;
                language      = language.swapEndian;
            }

            writeln(  "      cmap:" );
            writefln( "        format        : 0x%x: %d", format, format );
            writefln( "        length        : 0x%x: %d", length, length );
            writefln( "        language      : 0x%x: %d", language, language );
        }
    }


    void loadCmapTableFormat4( ref File f, size_t offset, ref CmapFormat4 table )
    {
        f.seek( offset );
        f.rawRead( ( cast( CmapFormat4Short* ) &table )[ 0 .. 1 ] );

        with ( table )
        {            
            version ( LittleEndian )
            {
                //format        = format.swapEndian; // swapped before
                length        = length.swapEndian;
                language      = language.swapEndian;
                segCountX2    = segCountX2.swapEndian;
                searchRange   = searchRange.swapEndian;
                entrySelector = entrySelector.swapEndian;
                rangeShift    = rangeShift.swapEndian;

//UInt16[SEGCOUNT]  endCode;         // Ending character code for each segment, last = 0xFFFF.
//UInt16            reservedPad;     // This value should be zero
//UInt16[SEGCOUNT]  startCode;       // Starting character code for each segment
//UInt16[SEGCOUNT]  idDelta;         // Delta for all character codes in segment
//UInt16[SEGCOUNT]  idRangeOffset;   // Offset in bytes to glyph indexArray, or 0
//UInt16[VARIABLE]  glyphIndexArray; // Glyph index array
            }

            writeln(  "      cmap:" );
            writefln( "        format        : 0x%x: %d", format, format );
            writefln( "        length        : 0x%x: %d", length, length );
            writefln( "        language      : 0x%x: %d", language, language );
            writefln( "        segCountX2    : 0x%x: %d", segCountX2, segCountX2 );
            writefln( "        searchRange   : 0x%x: %d", searchRange, searchRange );
            writefln( "        entrySelector : 0x%x: %d", entrySelector, entrySelector );
            writefln( "        rangeShift    : 0x%x: %d", rangeShift, rangeShift );

            //
            //arrays.length = length;
            //arrays = new ubyte[length];

            // endCode
            //f.seek( offset + CmapFormat4.arrays.offsetof );
            //arrays = f.rawRead( arrays );
            endCode.length   = segCountX2/2;
            endCode   = f.rawRead( endCode );

            foreach ( ref c; endCode )
            {
                c = c.swapEndian;
                //write( c, " " );
            }
            //writeln();

            // startCode
            startCode.length = segCountX2/2;
            f.seek( UInt16.sizeof, SEEK_CUR );
            startCode = f.rawRead( startCode );

            foreach ( ref c; startCode )
            {
                c = c.swapEndian;
                //write( c, " " );
            }
            //writeln();

            // idDelta
            idDelta.length = segCountX2/2;
            idDelta = f.rawRead( idDelta );
            foreach ( ref c; idDelta )
            {
                c = c.swapEndian;
                //write( c, " " );
            }
            //writeln();

            // idRangeOffset
            idRangeOffset.length = segCountX2/2;
            idRangeOffset = f.rawRead( idRangeOffset );
            foreach ( ref c; idRangeOffset )
            {
                c = c.swapEndian;
                //write( c, " " );
            }
            //writeln();

            // glyphIndexArray
            glyphIndexArray.length = length - ( CmapFormat4Short.sizeof - segCountX2/2*4 - UInt16.sizeof );
            glyphIndexArray = f.rawRead( glyphIndexArray );
            foreach ( ref c; glyphIndexArray )
            {
                c = c.swapEndian;
                //write( c, " " );
            }
            //writeln();

version (1)
{
            UInt16[1] _stub;
            f.rawRead( _stub );
            startCode = f.rawRead( startCode );
            //writeln( "arrays.length : ", arrays.length );
            writeln( "endCode.length   : ", endCode.length );
            writeln( "startCode.length : ", startCode.length );
            writeln( "length           : ", length );

            // Set array pointers
            //endCode         = cast( UInt16* ) arrays.ptr;
            //startCode       = cast( UInt16* ) ( ( cast( ubyte* ) endCode       ) + segCountX2 + UInt16.sizeof );
            //idDelta         = cast( UInt16* ) ( ( cast( ubyte* ) startCode     ) + segCountX2 );
            //idRangeOffset   = cast( UInt16* ) ( ( cast( ubyte* ) idDelta       ) + segCountX2 );
            //glyphIndexArray = cast( UInt16* ) ( ( cast( ubyte* ) idRangeOffset ) + segCountX2 );

            writeln( "segCountX2   : ", segCountX2 );
            writeln( "segCount     : ", segCountX2 / 2 );
            foreach( i; 0 .. segCountX2 / 2 )
            {
                if ( startCode[i] > endCode[i] )
                    writefln( " startCode[%d] .. endCode[%d] : %d .. %d", i, i, startCode[i], endCode[i] );
            }
        }
}
        //ushort charCode = 'A';
        //findGlyfFormat4( charCode, table );
    }


    void loadCmapTableFormat6( ref CmapFormat6 table )
    {
        // format 6
        with ( table )
        {            
            version ( LittleEndian )
            {
                //format        = format.swapEndian; // swapped before
                length     = length.swapEndian;
                language   = language.swapEndian;
                firstCode  = firstCode.swapEndian;
                entryCount = entryCount.swapEndian;
            }

            writeln(  "      cmap:" );
            writefln( "        format     : 0x%x: %d", format, format );
            writefln( "        length     : 0x%x: %d", length, length );
            writefln( "        language   : 0x%x: %d", language, language );
            writefln( "        firstCode  : 0x%x: %d", firstCode, firstCode );
            writefln( "        entryCount : 0x%x: %d", entryCount, entryCount );
        }
    }


    void loadCmapTableFormat8( ref CmapFormat8 table )
    {
        with ( table )
        {            
            version ( LittleEndian )
            {
                //format        = format.swapEndian; // swapped before
                length        = length.swapEndian;
                language      = language.swapEndian;
            }

            writeln(  "      cmap:" );
            writefln( "        format        : 0x%x: %d", format, format );
            writefln( "        length        : 0x%x: %d", length, length );
            writefln( "        language      : 0x%x: %d", language, language );
        }
    }


    void loadCmapTableFormat10( ref CmapFormat10 table )
    {
        with ( table )
        {            
            version ( LittleEndian )
            {
                //format        = format.swapEndian; // swapped before
                length        = length.swapEndian;
                language      = language.swapEndian;
                startCharCode = startCharCode.swapEndian;
                numChars      = numChars.swapEndian;
                nGroups       = nGroups.swapEndian;
            }

            writeln(  "      cmap:" );
            writefln( "        format        : 0x%x: %d", format, format );
            writefln( "        length        : 0x%x: %d", length, length );
            writefln( "        language      : 0x%x: %d", language, language );
            writefln( "        startCharCode : 0x%x: %d", startCharCode, startCharCode );
            writefln( "        numChars      : 0x%x: %d", numChars, numChars );
            writefln( "        nGroups       : 0x%x: %d", nGroups, nGroups );
        }
    }


    void loadCmapTableFormat12( ref CmapFormat12 table )
    {
        with ( table )
        {            
            version ( LittleEndian )
            {
                //format        = format.swapEndian; // swapped before
                length   = length.swapEndian;
                language = language.swapEndian;
                nGroups  = nGroups.swapEndian;
            }

            writeln(  "      cmap:" );
            writefln( "        format   : 0x%x: %d", format, format );
            writefln( "        length   : 0x%x: %d", length, length );
            writefln( "        language : 0x%x: %d", language, language );
            writefln( "        nGroups  : 0x%x: %d", nGroups, nGroups );
        }
    }


    void loadCmapTableFormat13( ref CmapFormat13 table )
    {
        with ( table )
        {            
            version ( LittleEndian )
            {
                //format        = format.swapEndian; // swapped before
                length   = length.swapEndian;
                language = language.swapEndian;
                nGroups  = nGroups.swapEndian;
            }

            writeln(  "      cmap:" );
            writefln( "        format   : 0x%x: %d", format, format );
            writefln( "        length   : 0x%x: %d", length, length );
            writefln( "        language : 0x%x: %d", language, language );
            writefln( "        nGroups  : 0x%x: %d", nGroups, nGroups );
        }
    }


    void loadCmapTableFormat14( ref CmapFormat14 table )
    {
        with ( table )
        {            
            version ( LittleEndian )
            {
                //format        = format.swapEndian; // swapped before
                length                = length.swapEndian;
                numVarSelectorRecords = numVarSelectorRecords.swapEndian;
            }

            writeln(  "      cmap:" );
            writefln( "        format                : 0x%x: %d", format, format );
            writefln( "        length                : 0x%x: %d", length, length );
            writefln( "        numVarSelectorRecords : 0x%x: %d", numVarSelectorRecords, numVarSelectorRecords );
        }
    }


    void readHeadTable( ref File f, uint32 offset )
    {
        f.seek( offset );
        f.rawRead( headTable );

        with ( headTable.ptr )
        {
            version ( LittleEndian ) 
            {
                version_           = version_.swapEndian;
                fontRevision       = fontRevision.swapEndian;
                checkSumAdjustment = checkSumAdjustment.swapEndian;
                magicNumber        = magicNumber.swapEndian;
                flags              = flags.swapEndian;
                unitsPerEm         = unitsPerEm.swapEndian;
                created            = created.swapEndian;
                modified           = modified.swapEndian;
                xMin               = xMin.swapEndian;
                yMin               = yMin.swapEndian;
                xMax               = xMax.swapEndian;
                yMax               = yMax.swapEndian;
                macStyle           = macStyle.swapEndian;
                lowestRecPPEM      = lowestRecPPEM.swapEndian;
                fontDirectionHint  = fontDirectionHint.swapEndian;
                indexToLocFormat   = indexToLocFormat.swapEndian;
                glyphDataFormat    = glyphDataFormat.swapEndian;
            }

            writefln( "  head:" );
            writefln( "    version            : 0x%x", version_ );
            writefln( "    fontRevision       : 0x%x", fontRevision );
            writefln( "    checkSumAdjustment : 0x%x", checkSumAdjustment );
            writefln( "    magicNumber        : 0x%x", magicNumber );
            writefln( "    flags              : 0x%x: %s", flags, flagsToString( flags ) );
            writefln( "    unitsPerEm         : %d", unitsPerEm );
            writefln( "    created            : 0x%08x: %s", created.a, created.toString );
            writefln( "    modified           : 0x%08x: %s", modified.a, modified.toString );
            writefln( "    xMin               : 0x%04x: %d: %f", xMin, xMin, xMin / 65536.0f );
            writefln( "    yMin               : 0x%04x: %d: %f", yMin, yMin, yMin / 65536.0f );
            writefln( "    xMax               : 0x%04x: %d: %f", xMax, xMax, xMax / 65536.0f );
            writefln( "    yMax               : 0x%04x: %d: %f", yMax, yMax, yMax / 65536.0f );
            writefln( "    macStyle           : 0x%x: %s", macStyle, macStyleToString( macStyle ) );
            writefln( "    lowestRecPPEM      : %d", lowestRecPPEM );
            writefln( "    fontDirectionHint  : %d: %s", fontDirectionHint, fontDirectionHintToString( fontDirectionHint ) );
            writefln( "    indexToLocFormat   : %d", indexToLocFormat );
            writefln( "    glyphDataFormat    : %d", glyphDataFormat );
        }
    }


    void readLocaTable( ref File f, uint32 offset )
    {
        // headTable.indexToLocFormat; // 0 for short offsets, 1 for long
        auto esize = headTable.ptr.indexToLocFormat == 0 ? uint16.sizeof : uint32.sizeof;
        locaTable.length = maxpTable.ptr.numGlyphs;

        f.seek( offset );
        f.rawRead( locaTable );

        // 1st glyph is stub glyph
    }


    void readMaxpTable( ref File f, uint32 offset )
    {
        f.seek( offset );
        f.rawRead( maxpTable );

        with ( maxpTable.ptr )
        {
            version ( LittleEndian ) 
            {
                version_              = version_.swapEndian;
                numGlyphs             = numGlyphs.swapEndian;
                maxPoints             = maxPoints.swapEndian;
                maxContours           = maxContours.swapEndian;
                maxComponentPoints    = maxComponentPoints.swapEndian;
                maxComponentContours  = maxComponentContours.swapEndian;
                maxZones              = maxZones.swapEndian;
                maxTwilightPoints     = maxTwilightPoints.swapEndian;
                maxStorage            = maxStorage.swapEndian;
                maxFunctionDefs       = maxFunctionDefs.swapEndian;
                maxInstructionDefs    = maxInstructionDefs.swapEndian;
                maxStackElements      = maxStackElements.swapEndian;
                maxSizeOfInstructions = maxSizeOfInstructions.swapEndian;
                maxComponentElements  = maxComponentElements.swapEndian;
                maxComponentDepth     = maxComponentDepth.swapEndian;
            }

            writefln( "  head:" );
            writefln( "    version               : 0x%x", version_ );
            writefln( "    numGlyphs             : 0x%x", numGlyphs );
            writefln( "    maxPoints             : 0x%x", maxPoints );
            writefln( "    maxContours           : 0x%x", maxContours );
            writefln( "    maxComponentPoints    : 0x%x", maxComponentPoints );
            writefln( "    maxComponentContours  : 0x%x", maxComponentContours );
            writefln( "    maxZones              : 0x%x", maxZones );
            writefln( "    maxTwilightPoints     : 0x%x", maxTwilightPoints );
            writefln( "    maxStorage            : 0x%x", maxStorage );
            writefln( "    maxFunctionDefs       : 0x%x", maxFunctionDefs );
            writefln( "    maxInstructionDefs    : 0x%x", maxInstructionDefs );
            writefln( "    maxStackElements      : 0x%x", maxStackElements );
            writefln( "    maxSizeOfInstructions : 0x%x", maxSizeOfInstructions );
            writefln( "    maxComponentElements  : 0x%x", maxComponentElements );
            writefln( "    maxComponentDepth     : 0x%x", maxComponentDepth );
        }
    }


    void readHheaTable( ref File f, uint32 offset )
    {
        f.seek( offset );
        f.rawRead( hheaTable );

        with ( hheaTable.ptr )
        {
            version ( LittleEndian ) 
            {
                version_              = version_.swapEndian;
                ascent                = ascent.swapEndian; 
                descent               = descent.swapEndian; 
                lineGap               = lineGap.swapEndian; 
                advanceWidthMax       = advanceWidthMax.swapEndian; 
                minLeftSideBearing    = minLeftSideBearing.swapEndian; 
                minRightSideBearing   = minRightSideBearing.swapEndian; 
                xMaxExtent            = xMaxExtent.swapEndian; 
                caretSlopeRise        = caretSlopeRise.swapEndian; 
                caretSlopeRun         = caretSlopeRun.swapEndian; 
                caretOffset           = caretOffset.swapEndian; 
                reserved              = reserved.swapEndian; 
                reserved2             = reserved2.swapEndian; 
                reserved3             = reserved3.swapEndian; 
                reserved4             = reserved4.swapEndian; 
                metricDataFormat      = metricDataFormat.swapEndian; 
                numOfLongHorMetrics   = numOfLongHorMetrics.swapEndian; 
            }

            writefln( "  head:" );
            writefln( "    version             : 0x%x", version_ );
            writefln( "    ascent              : 0x%x", ascent );
            writefln( "    descent             : 0x%x", descent );
            writefln( "    lineGap             : 0x%x", lineGap );
            writefln( "    advanceWidthMax     : 0x%x", advanceWidthMax );
            writefln( "    minLeftSideBearing  : 0x%x", minLeftSideBearing );
            writefln( "    minRightSideBearing : 0x%x", minRightSideBearing );
            writefln( "    xMaxExtent          : 0x%x", xMaxExtent );
            writefln( "    caretSlopeRise      : 0x%x", caretSlopeRise );
            writefln( "    caretSlopeRun       : 0x%x", caretSlopeRun );
            writefln( "    caretOffset         : 0x%x", caretOffset );
            writefln( "    reserved            : 0x%x", reserved );
            writefln( "    reserved2           : 0x%x", reserved2 );
            writefln( "    reserved3           : 0x%x", reserved3 );
            writefln( "    reserved4           : 0x%x", reserved4 );
            writefln( "    metricDataFormat    : 0x%x", metricDataFormat );
            writefln( "    numOfLongHorMetrics : 0x%x", numOfLongHorMetrics );
        }
    }


    // after hhea, maxp
    void readHmtxTable( ref File f, uint32 offset )
    {
        f.seek( offset );

        hmtxTable.ptr.hMetrics.length = hheaTable.ptr.numOfLongHorMetrics;
        f.rawRead( hmtxTable.ptr.hMetrics );

        hmtxTable.ptr.leftSideBearing.length = maxpTable.ptr.numGlyphs - hheaTable.ptr.numOfLongHorMetrics;
        f.rawRead( hmtxTable.ptr.leftSideBearing );

        with ( hmtxTable.ptr )
        {
            version ( LittleEndian ) 
            {
                foreach ( ref e; hMetrics )
                {
                    e.advanceWidth    = e.advanceWidth.swapEndian;
                    e.leftSideBearing = e.leftSideBearing.swapEndian;
                }
                foreach ( ref e; leftSideBearing )
                {
                    e = e.swapEndian;
                }
            }

            //writefln( "    numOfLongHorMetrics : 0x%x", numOfLongHorMetrics );
        }
    }


    // after hhea, maxp
    void readNameTable( ref File f, uint32 offset )
    {
        f.seek( offset );
        f.rawRead( ( cast( NameTableShort* ) nameTable.ptr )[ 0 .. 1 ] );

        with ( nameTable.ptr )
        {
            version ( LittleEndian ) 
            {
                count        = count.swapEndian;
                stringOffset = stringOffset.swapEndian;
            }

            nameRecord.length = count;
            f.rawRead( nameRecord );

            version ( LittleEndian ) 
            {
                foreach ( ref rec; nameRecord )
                {
                    rec.platformID         = rec.platformID.swapEndian;
                    rec.platformSpecificID = rec.platformSpecificID.swapEndian;
                    rec.languageID         = rec.languageID.swapEndian;
                    rec.nameID             = rec.nameID.swapEndian;
                    rec.length             = rec.length.swapEndian;
                    rec.offset             = rec.offset.swapEndian;
                }
            }
            //writefln( "    numOfLongHorMetrics : 0x%x", numOfLongHorMetrics );
        }
    }
}


auto findGlyfFormat4( in ushort charCode, in ref CmapFormat4 table, in ref LocaTable[] locaTable )
{
    // Search charcode in array endCode
    auto i =
        assumeSorted( table.endCode )
            .lowerBound( charCode )
            .length;

    writeln( "i: ", i);

    auto startCode = table.startCode[ i ];

    // Test startCode
    if ( startCode <= charCode )
    {
        // OK
        auto glyphIndex = 
            table.glyphIndexArray[ charCode - startCode ] ; //  + table.idDelta[ i ]

        writefln( "glyphIndex: %d", glyphIndex );

        auto glyphOffset = locaTable[ glyphIndex ];

        writefln( "glyphOffset: %d", glyphOffset );
    }
    else

    // Test for range end
    if ( table.endCode[ i ] == 0xFFFF )
    {
        // NOT FOUND
        writeln( "cmap offset: ", "NOT FOUND" );
    }
    else

    {
        // NOT FOUND
        writeln( "cmap offset: ", "NOT FOUND" );
    }
}


/*
void binarySearch( UInt16* array, UInt16 charCode )
{
    auto a = array;
    auto b = cast( UInt16* ) ( cast( ubyte* ) array + table.segCountX2 );
    auto searchRange = table.searchRange;

    L_check_again:
    auto i = a + searchRange / 2;

    auto e = array[ i ];

    if ( e == charCode )
    {
        // OK
    }
    else

    if ( e < charCode )
    {
        // to Left
        searchRange /= 2;
        if ( searchRange != 0 )
        {
            b = i;
            goto L_check_again;
        }
        else
        {
            // NOT FOUND
        }
    }
    else

    {
        // to Right
        searchRange /= 2;
        if ( searchRange != 0 )
        {
            a = i;
            goto L_check_again;
        }
        else
        {
            // NOT FOUND
        }
    }
}
*/

