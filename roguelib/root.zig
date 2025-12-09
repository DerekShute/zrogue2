//!
//! roguelib
//!

pub const Action = @import("Action.zig");
pub const Entity = @import("Entity.zig");
pub const Feature = @import("maptile.zig").Feature;
pub const Grid = @import("grid.zig").Grid;
pub const Map = @import("Map.zig");
pub const MapTile = @import("maptile.zig").MapTile;
pub const MessageLog = @import("MessageLog.zig");
pub const Pos = @import("Pos.zig");
pub const Region = @import("Region.zig");
pub const Room = @import("map/Room.zig"); // TODO Not sure about this
pub const Tileset = @import("maptile.zig").Tileset;

//
// Unit Test Breakout
//

comptime {
    _ = @import("Action.zig");
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
