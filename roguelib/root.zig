//!
//! roguelib
//!

pub const Pos = @import("Pos.zig");
pub const Region = @import("Region.zig");
pub const Grid = @import("grid.zig").Grid;
pub const MessageLog = @import("MessageLog.zig");

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
// Visible thing at map space
//
// TODO Future: union with monster types and objects?
//

pub const MapTile = enum {
    unknown,
    floor,
    wall, // Start of features
    trap,
    door,
    stairs_down,
    stairs_up, // Last feature
    gold,
    player,

    pub fn isFeature(self: MapTile) bool {
        const s: usize = @intFromEnum(self);
        return switch (s) {
            @intFromEnum(MapTile.wall)...@intFromEnum(MapTile.stairs_up) => true,
            else => false,
        };
    }

    pub fn isPassable(self: MapTile) bool {
        return (self != .wall);
    }
};

//
// Unit Test Breakout
//

comptime {
    _ = @import("Pos.zig");
    _ = @import("Region.zig");
    _ = @import("grid.zig");
    _ = @import("MessageLog.zig");
}

// EOF
