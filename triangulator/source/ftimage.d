module ftimage;

auto FT_CURVE_TAG( T )( T flag )  { return ( flag & 0x03 ); }

  /* see the `tags` field in `FT_Outline` for a description of the values */
//enum FT_CURVE_TAG_ON            = 0x01;
//enum FT_CURVE_TAG_CONIC         = 0x00;
//enum FT_CURVE_TAG_CUBIC         = 0x02;

enum FT_CURVE_TAG_HAS_SCANMODE  = 0x04;

enum FT_CURVE_TAG_TOUCH_X       = 0x08;  /* reserved for TrueType hinter */
enum FT_CURVE_TAG_TOUCH_Y       = 0x10;  /* reserved for TrueType hinter */

enum FT_CURVE_TAG_TOUCH_BOTH    = ( FT_CURVE_TAG_TOUCH_X | FT_CURVE_TAG_TOUCH_Y );
  /* values 0x20, 0x40, and 0x80 are reserved */


  /* these constants are deprecated; use the corresponding */
  /* `FT_CURVE_TAG_XXX` values instead                     */
//enum FT_Curve_Tag_On       = FT_CURVE_TAG_ON;
//enum FT_Curve_Tag_Conic    = FT_CURVE_TAG_CONIC;
//enum FT_Curve_Tag_Cubic    = FT_CURVE_TAG_CUBIC;
//enum FT_Curve_Tag_Touch_X  = FT_CURVE_TAG_TOUCH_X;
//enum FT_Curve_Tag_Touch_Y  = FT_CURVE_TAG_TOUCH_Y;
