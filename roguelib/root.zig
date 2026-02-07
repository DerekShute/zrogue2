//!
//! roguelib
//!

pub const Action = @import("Action.zig");
pub const Client = @import("Client.zig");
pub const Entity = @import("Entity.zig");
pub const Feature = @import("Feature.zig");
pub const Grid = @import("grid.zig").Grid;
pub const Map = @import("Map.zig");
pub const MapTile = @import("maptile.zig").MapTile;
pub const Pos = @import("Pos.zig");
pub const Region = @import("Region.zig");
pub const Room = @import("map/Room.zig");
pub const Tileset = @import("maptile.zig").Tileset;

pub const mapgen = @import("mapgen.zig");
//
// Unit Test Breakout
//

comptime {
    _ = @import("Action.zig");
    _ = @import("Client.zig");
    _ = @import("client/MessageLog.zig");
    _ = @import("Entity.zig");
    _ = @import("grid.zig");
    _ = @import("maptile.zig");
    _ = @import("Map.zig");
    _ = @import("mapgen.zig");
    _ = @import("Pos.zig");
    _ = @import("queue.zig");
    _ = @import("Region.zig");
    _ = @import("map/Place.zig");
    _ = @import("map/Room.zig");
}

// EOF
