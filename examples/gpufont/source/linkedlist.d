module linkedlist;

import core.stdc.stdlib;
import core.stdc.stdint;

alias LLNodeID = ushort ; /* sets a hard limit on linked list size */
enum LL_BAD_INDEX = 0xFFFF;

/* Note: the list is cyclic. Both prev and next will point to the same node if the list has only one node */
struct LLNode
{
	LLNodeID prev, next;
}

struct LinkedList
{
	LLNode*   pool; /* pointer to the node pool */
	LLNodeID* free_root_p; /* Pointer to root index of the "empty" list. Can be used to make multiple lists share the same pool. Equals LL_BAD_INDEX if the pool has no free slots */
	LLNodeID  root; /* root node of the "full" list. Use this to iterate the list. Equal to LL_BAD_INDEX if the list is empty. Start iterating the list from this node */
	LLNodeID  length; /* how many nodes in the "full" list */
	LLNodeID  free_root; /* If this list is the only user of the pool, then root_of_empty points to this. Otherwise this is unused */
}

/* Used to create an empty list. Can use any memory (stack/heap/whatever)
Note: the actual data of nodes' is kept in a separate array and accessed via node indices
To use the entire pool, set first_node=0 and last_node=(size of the pool minus one) */
//void init_list( LinkedList list[1], LLNode pool[], size_t first_node, size_t last_node );

/* Removes a node from the list */
//void pop_node( LinkedList list[1], LLNodeID node );

/* Moves a node from the "free" list to the "used" list. The new node is linked before <before_this_node> if it isn't LL_BAD_INDEX.
Returns LL_BAD_INDEX if the "free" list is empty (=the pool is exhausted) */
//LLNodeID add_node( LinkedList list[1], LLNodeID before_this_node );

/* Used to get next and previous node indices */
pragma( inline, true )
auto LL_PREV( T1, T2 )( T1 list, T2 node_index ) 
{
	return list.pool[ node_index ].prev;
}
pragma( inline, true )
auto LL_NEXT( T1, T2 )( T1 list, T2 node_index ) 
{
	return list.pool[ node_index ].next;
}

/* mostly internal use only */
//LLNodeID unlink_node( LLNode pool[], LLNodeID root[1], LLNodeID used_node );
//LLNodeID link_node( LLNode pool[], LLNodeID root[1], LLNodeID unused_node );


void init_list( LinkedList* list, LLNode* pool, LLNodeID first_node, LLNodeID last_node )
{
	assert( last_node < (1<<8*LLNodeID.sizeof) );
	
	list.pool = pool;
	list.free_root_p = &list.free_root;
	list.length = 0;
	list.root = LL_BAD_INDEX;
	list.free_root = LL_BAD_INDEX;
	
	if ( last_node >= first_node && last_node != LL_BAD_INDEX )
	{
		LLNodeID n;
		
		list.free_root = first_node;
		
		pool[ first_node ].prev = last_node;
		pool[ first_node ].next = cast( LLNodeID ) ( first_node + 1 );
		
		pool[ last_node ].prev = cast( LLNodeID ) ( last_node - 1 );
		pool[ last_node ].next = first_node;
		
		for ( n= cast( LLNodeID ) ( first_node+1 ); n<last_node; n++ ) {
			pool[n].prev = cast( LLNodeID ) ( n - 1 );
			pool[n].next = cast( LLNodeID ) ( n + 1 );
		}
	}
}

LLNodeID unlink_node( LLNode* pool, LLNodeID* root, LLNodeID node_index )
{
	LLNode *node = pool + node_index;
	if ( node.prev == node.next ) 
	{
		/* The list had only 1 node before but now it becomes completely empty */
		*root = LL_BAD_INDEX;
	} 
	else 
	{
		pool[ node.prev ].next = node.next;
		pool[ node.next ].prev = node.prev;
		if ( *root == node_index )
			*root = node.next;
	}
	return node_index;
}

LLNodeID link_node( LLNode* pool, LLNodeID* root_index, LLNodeID node_index )
{
	LLNode *node = pool + node_index;
	
	if ( *root_index == LL_BAD_INDEX )
	{
		/* List was empty */
		node.prev = node_index;
		node.next = node_index;
	}
	else
	{
		LLNode *root = pool + *root_index;
		pool[ root.prev ].next = node_index;
		node.prev = root.prev;
		node.next = *root_index;
		root.prev = node_index;
	}
	
	return *root_index = node_index;
}

LLNodeID add_node( LinkedList* list, LLNodeID before_this_node )
{
	if ( *list.free_root_p == LL_BAD_INDEX )
		return LL_BAD_INDEX;
	
	list.length += 1;
	
	return 
		link_node( 
			list.pool,
			( before_this_node == LL_BAD_INDEX ) ? 
				&list.root : 
				&before_this_node,
			unlink_node( list.pool, list.free_root_p, *list.free_root_p )
		);
}

void pop_node( LinkedList* list, LLNodeID node )
{
	assert( list.length > 0 );
	list.length -= 1;
	
	/* Unlink a node from the "full" list and link_node that node to the "empty" list */
	link_node( 
		list.pool, 
		list.free_root_p, 
		unlink_node( list.pool, &list.root, node ) 
	);
}
