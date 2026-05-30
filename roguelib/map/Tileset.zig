//!
//! Tileset - tiles at a location (floor, entity, item).
//!
//! This is an API convenience for queries into the map
//!

const Tile = @import("common").Tile;

const Self = @This();

//
// Members
//

floor: Tile = undefined,
entity: Tile = undefined,
item: Tile = undefined,

//
// Lifecycle
//

pub const init: Self = .{
    .floor = .none,
    .entity = .none,
    .item = .none,
};

// EOF
