module ui.fonts;

version ( FontConfig ):
public import fontconfig.fontconfig;
import core.stdc.stdio  : printf;
import core.stdc.string : strlen;
import core.stdc.string : memcpy;
import core.stdc.stdlib : malloc;
import core.stdc.stdlib : free;

/** 
 * Returns C string contains path to the OS font file
 * After using program showld free string with freeFontRecord().
 */
nothrow @nogc
FontRec* queryFont( immutable char* family, int style, float height, float slant, float outline )
{
    FcPattern* pat;
    FcPattern* match;
    FcChar8*   path;
    FcResult   result;        

    pat = FcPatternCreate();

    // family
    FcPatternAddString( pat, FC_FAMILY, /*cast( const FcChar8* )*/ family );
    
    // bold
    if ( style == 1 ) 
    { 
        FcPatternAddInteger( pat, FC_WEIGHT, FC_WEIGHT_BOLD );
    }

    // italic
    if ( style == 2 ) 
    { 
        FcPatternAddInteger( pat, FC_SLANT, FC_SLANT_ITALIC );
    }

    // dpi
    FcPatternAddDouble( pat, FC_DPI, 72.0 ); /* 72 dpi = 1 pixel per 'point' */

    // size
    FcPatternAddDouble( pat, FC_SIZE, height );

    //
    FcDefaultSubstitute( pat );                     /* fill in other expected pattern fields */
    FcConfigSubstitute( null, pat, FcMatchKind.FcMatchPattern );   /* apply any system/user config rules */

    //
    match = FcFontMatch( null, pat, &result );         /* find 'best' matching font */

    if ( result != FcResult.FcResultMatch || !match ) 
    {
        /* FIXME: better error reporting/handling here...
        * want to minimise the situations where opendefaultfont gives you *nothing* */
        return null;
    }

    // file name, face index
    FcPatternGetString( match, FC_FILE, 0, &path );

    //
    FontRec* fontRecord = null;
    if ( path )
    {
        fontRecord = cast( FontRec* ) malloc( FontRec.sizeof );

        size_t l = strlen( path );
        fontRecord.fileName = cast( char* ) malloc( l );
        memcpy( fontRecord.fileName, path, l );

        // face index
        FcPatternGetInteger( match, FC_INDEX, 0, &fontRecord.faceIndex );
    }

    //
    FcPatternDestroy( match );
    FcPatternDestroy( pat );

    return fontRecord;
}


void freeFontRecord( FontRec* fontRecord )
{
    if ( fontRecord.fileName)
    {
        free( fontRecord.fileName );
    }

    free( fontRecord );
}


struct FontRec
{
    char* fileName;
    int   faceIndex;
}
