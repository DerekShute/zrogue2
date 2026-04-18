//!
//! roguelib
//!

pub const Action = @import("Action.zig");
pub const Client = @import("Client.zig");
pub const Command = Client.Command;
pub const Entity = @import("Entity.zig");
pub const Feature = @import("Feature.zig");
pub const Grid = @import("grid.zig").Grid;
pub const Map = @import("Map.zig");
pub const MapTile = @import("maptile.zig").MapTile;
pub const Player = @import("Player.zig");
pub const Pos = @import("Pos.zig");
pub const Region = @import("Region.zig");
pub const Room = @import("map/Room.zig");
pub const Tileset = @import("maptile.zig").Tileset;

pub const mapgen = @import("mapgen.zig");

//
// Unit Test Breakout
//

test {
    @import("std").testing.refAllDecls(@This());
}

// EOF
