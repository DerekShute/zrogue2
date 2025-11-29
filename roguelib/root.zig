//!
//! roguelib
//!

pub const Pos = @import("Pos.zig");
pub const Region = @import("Region.zig");
pub const Grid = @import("grid.zig").Grid;
pub const MapTile = @import("maptile.zig").MapTile;
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
// Unit Test Breakout
//

comptime {
    _ = @import("Pos.zig");
    _ = @import("Region.zig");
    _ = @import("grid.zig");
    _ = @import("maptile.zig");
    _ = @import("MessageLog.zig");
}

// EOF
