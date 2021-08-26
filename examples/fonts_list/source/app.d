import core.stdc.stdio  : printf;
import core.stdc.stdlib : free;
import ui.fonts;
import std.string : toStringz;
	

void main() 
{
	auto rec = 
		queryFont( 
			/* family  */ "arial".toStringz,
			/* style   */ 0, 
			/* height  */ 16, 
			/* slant   */ 0, 
			/* outline */ 0.0f
		);

	if ( rec )
	{
		printf( "fontFilePath: %s\n", rec.fileName );
		freeFontRecord( rec );
	}
	else
	{
		printf( "fontFilePath: null\n" );
	}
}

