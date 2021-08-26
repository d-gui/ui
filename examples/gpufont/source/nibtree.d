module nibtree;

import core.stdc.stdint;
//#include <stdlib.h>
import core.stdc.stdlib;
//#include <string.h>
import core.stdc.string;

/* This module implements a 16-tree that maps integers to integers (e.g. it can be at most 8 levels deep for a 32-bit integer)
I call it a "nibble tree" because of the way it is searched.
Intented to be used by font_file.c for character code to glyph index translation */

/* Should be the lowest common size of GlyphIndex and the biggest real world character code */
alias NibValue = uint32_t;

/* This structure must be zero-initialized before it can be used !! */
struct NibTree
{
    NibValue *data; /* can be free'd */
    NibValue data_len; /* how many NibValues have been allocated */
    NibValue next_offset; /* where to add the next node */
}

//

static 
int initialize( NibTree* tree )
{
    NibValue len = 1024;
    
    tree.data = cast(typeof(tree.data)) malloc( ( NibValue ).sizeof * len );
    tree.data_len = len;
    tree.next_offset = 16;
    
    if ( !tree.data )
        return 0;
    
    /* clear the root branch with invalid offsets */
    memset( tree.data, 0, ( NibValue ).sizeof * 16 );
    
    return 1;
}

static 
NibValue add_node( NibTree* tree )
{
    NibValue pos = tree.next_offset;
    NibValue end = tree.next_offset + 16;
    
    while( end > tree.data_len )
    {
        NibValue new_len = 2 * tree.data_len;
        NibValue *new_data;
        
        new_data = cast(typeof(new_data)) realloc( tree.data, ( NibValue ).sizeof * new_len );
        if ( !new_data )
            return 0;
        
        tree.data = new_data;
        tree.data_len = new_len;
    }
    
    tree.next_offset = end;
    return pos;
}

int nibtree_set( NibTree* tree, NibValue key, NibValue new_value )
{
    NibValue *node;
    NibValue nibble_bit_pos = 28;
    NibValue nibble, offset;
    
    if ( !tree.data ) {
        if ( !initialize( tree ) )
            return 0;
    }
    
    node = tree.data;
    
    do {
        nibble = ( key >> nibble_bit_pos ) & 0xF;
        nibble_bit_pos -= 4;
        offset = node[ nibble ];
        
        if ( !offset )
        {
            /* Branch doesn't exist so create it */
            
            size_t parent_index = node - tree.data;
            offset = add_node( tree );
            
            if ( !offset )
                return 0;
            
            tree.data[ parent_index + nibble ] = offset;
            memset( tree.data + offset, 0, ( NibValue ).sizeof * 16 );
        }
        
        node = tree.data + offset;
    } while( nibble_bit_pos );
    
    node[ key & 0xF ] = new_value;
    return 1;
}

NibValue nibtree_get( NibTree* tree, NibValue key )
{
    NibValue *node = tree.data;
    NibValue nibble_pos = 28;
    NibValue nibble, offset;
    
    if ( !node )
        return 0;
    
    do {
        nibble = ( key >> nibble_pos ) & 0xF;
        nibble_pos -= 4;
        offset = node[ nibble ];
        
        if ( !offset )
            return 0;
        
        node = tree.data + offset;
    } while( nibble_pos );
    
    return node[ key & 0xF ];
}
