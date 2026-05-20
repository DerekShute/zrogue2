//!
//! Tileset - tiles at a location (floor, entity, feature).  This represents
//!    the actual, rather than what is presented to a player.
//!
//! FUTURE: lighting, feature
//!
pub const MapTile = @import("common").MapTile;

const Self = @This();

//
// Members
//

floor: MapTile,
entity: MapTile,
item: MapTile,

//
// Lifecycle
//

pub const init: Self = .{
    .floor = .init,
    .entity = .init,
    .item = .init,
};

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
