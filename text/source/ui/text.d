module ui.text;

version ( GL3 ):
version ( HarfBuzz ):
import deps.gl3;
import deps.harfbuzz;
import core.stdc.stdio  : printf;
import core.stdc.string : strlen;
import core.stdc.string : memcpy;
import core.stdc.stdlib : malloc;
import ui.shaders       : linearShader;
import ui.vertex        : Vertex5;
import ui.glerrors      : checkGlError;


nothrow @nogc
void drawText( 
    string         text,              // text to draw
    int            x,                 // positions in window
    int            y, 
    float          r,                 // color
    float          g, 
    float          b,
    string         family,            // font family
    uint           size,              // font size
    uint           weight    = 0,     // font bold
    uint           slant     = 0,
    uint           dpi       = 96,    // default: 96 dot per pixel for Windows/Linux, 72 for Mac
    string         lang      = "en",  // default: "en". BCP 47 language tag
    hb_script_t    script    = HB_SCRIPT_LATIN,
    hb_direction_t direction = HB_DIRECTION_LTR
)
{
    auto fontRec = queryFont( family.toStringz, weight, size, slant, 0 );

    if ( fontRec !is null )
    {
        //auto shaper = HBShaper( fontFilePath, size );

        //HBText hbt = 
        //    {
        //        text,
        //        lang, // BCP 47 language tag
        //        script,
        //        direction
        //    };

        // render glyph atlas using glyph cache into the GL texture
        //auto atlasPixmap = malloc( 128 * glyphWidth * glyphHeight );

        ////
        //StackArray!( MyMesh, 30 ) meshes;

        //shaper.drawText( &hbt, 0, 0, &meshes );

        //gl.render( &meshes );

        // Load Font
        //   able caching here
        //     caching for face : 
        //       Face[ fileName ] faces
        //       Face[ fileName ][ face_index ] faces
        FT_Face face;
        auto err = 
            FT_New_Face( 
                ft,
                fontRec.fileName,
                fontRec.faceIndex,
                &face
            );

        // Load Glyph outline. Glyph points and controls - is outline
        err = 
            FT_Load_Glyph( 
                face,
                glyphIndex,
                FT_LOAD_DEFAULT 
            );

        // Atlas and Glyph position in Atlas
        FT_Bitmap target;
        target.buffer       = atlasPixmap + glyphOffset;
        target.rows         = glyph_height;
        target.width        = glyph_width;
        target.pitch        = atlasPixmap_pitch;
        target.num_grays    = 255;
        target.pixel_mode   = FT_PIXEL_MODE_GRAY;

        // Render glyph to Atlas
        FT_Raster_Params params;
        params.target = &target;
        params.flags  = FT_RASTER_FLAG_DIRECT;

        err = 
            FT_Outline_Render( 
                ft,
                &face.glyph.outline,
                &params 
            );

        //
        free( fontFilePath );
    }
    else
    {
        printf( "error: drawText(): can't find font: %s, %d\n", family.toStringz, size );
    }
}


// drawText
//   text
//     queryFonts
//       FC:
//           FcPatternCreate
//           FcPatternAddString  family
//           FcPatternAddInteger weight
//           FcPatternAddInteger slant
//           FcPatternAddDouble  dpi
//           FcPatternAddDouble  scale
//           FcPatternAddDouble  size
//           FcDefaultSubstitute
//           FcConfigSubstitute
//           FcFontMatch
//           FcPatternGetString
//       fontFile
//     HBShaper
//       FT:
//         FT_New_Face
//         FT_Set_Char_Size
//       HB:
//         hb_ft_font_create
//         hb_buffer_create
//         hb_buffer_allocation_successful
//     HBText
//       data
//       language
//       script
//       direction
//     HBShaper.drawText
//       HBText
//       HB: 
//         hb_buffer_reset
//         hb_buffer_set_direction
//         hb_buffer_set_script
//         hb_language_from_string
//         hb_buffer_set_language
//         hb_buffer_add_utf8
//         hb_shape
//         hb_buffer_get_glyph_infos
//           glyphInfo
//         hb_buffer_get_glyph_positions
//       allocate glyphes
//         glyphes
//       foreach glyph in glyphInfo:
//         glyph.codepoint
//           glyphIndex
//         glyphCache.readCreate
//           read
//             fontFace
//             fontSize
//             glyphIndex
//             glyph
//           create 
//             rasterize
//               FT: 
//                 FT_Load_Glyph
//                 FT_Render_Glyph // depends from FT_Set_Char_Size
//                   bitmap
//             storage[ fontFace ][ fontSize ][ glyphIndex ] = glyph
//             glyph
//           copy_to_big_pixmap
//           save_position_in_big_pixmap
//           update_in_glyphes
//
//     uploadTexture
//       glyphCache.GlyphSet.big_pixmap
//       GL: 
//         glGenTextures
//         glBindTexture
//         glTexImage2D
//         glGenerateMipmap
//
//   render
//     GL:
//       glUseProgram
//       glUniform1i
//       glActiveTexture
//       glGenBuffers
//       glGenVertexArrays
//       glBindVertexArray
//       foreach glyph in glyphInfo:
//         glBindTexture
//         glBindBuffer
//         glBufferData
//         glDrawArrays

// allocate
//   hb_buffer_pre_allocate
//     hb_glyph_info_t.sizeof * glyphsCount
//     Glyph.sizeof * glyphsCount
//

// HB + FT
//   hb_ft_face_create_cached

// GlyphCache
//   allocated at once
//   +-------+-------+-------+---------+
//   | Glyph | Glyph | Glyph | pixmaps |
//   +-------+-------+-------+---------+

// FreeType cache
// FTC_Manager_New
// 

// buffer = malloc( align2( w * h * N ) );
// FT_Outline_Render
//   params
//     flag
//       FT_RASTER_FLAG_DIRECT
//     target    // FT_Bitmap
//       buffer  // buffer + left + ( top * buffer.width )
//       putch   // buffer.width


// lookup font
//   font
//   lookup glyph
//     glyph
//     render


