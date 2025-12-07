//!
//! roguelib
//!

pub const Entity = @import("Entity.zig");
pub const Grid = @import("grid.zig").Grid;
pub const Map = @import("Map.zig");
pub const MapTile = @import("maptile.zig").MapTile;
pub const MessageLog = @import("MessageLog.zig");
pub const Pos = @import("Pos.zig");
pub const Region = @import("Region.zig");
pub const Room = @import("map/Room.zig"); // TODO Not sure about this
pub const Tileset = @import("maptile.zig").Tileset;

//
// Input abstraction
//
// REFACTOR: is this an input.zig thing?
// REFACTOR: Partially duplicates ThingAction.type
pub const Command = enum {
    wait,
    quit,
    go_north, // 'up'/'down' confusing w/r/t stairs
    go_east,
    go_south,
    go_west,
    ascend,
    descend,
    help,
    take_item,
    search,
};

//
// Unit Test Breakout
//

comptime {
    _ = @import("Entity.zig");
    _ = @import("grid.zig");
    _ = @import("maptile.zig");
    _ = @import("Map.zig");
    _ = @import("MessageLog.zig");
    _ = @import("Pos.zig");
    _ = @import("Region.zig");
    _ = @import("map/Place.zig");
    _ = @import("map/Room.zig");
}

// EOF
