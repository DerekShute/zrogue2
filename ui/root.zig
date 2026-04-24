//!
//! UI-related abstractions and utilities that all sort of go together
//!

//
// Command abstraction
//

// TODO: converge on using Action

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
// Maptile and Tileset
//

// TODO: break out item vs entity vs floor as separate tiles
pub const MapTile = enum(u8) {
    unknown,
    floor,
    wall, // Start of features
    trap, // visible trap
    door,
    stairs_down,
    stairs_up, // Last feature
    gold,
    player,

    pub fn isFeature(self: MapTile) bool {
        const s: usize = @intFromEnum(self);
        const wall = @intFromEnum(MapTile.wall);
        const stairs_up = @intFromEnum(MapTile.stairs_up);
        return switch (s) {
            wall...stairs_up => true,
            else => false,
        };
    }

    pub fn isPassable(self: MapTile) bool {
        return (self != .wall);
    }
};

//
// DisplayTile: the set of per-square information presented to the player
// eyeball.  The presentation can decide how to layer the information and
// whether to retain out-of-view areas as part of the display
//

pub const DisplayTile = struct {
    entity: u8,
    item: u8,
    floor: u8,
    visible: bool,

    // Locked constant - 'you do not know what is right here'
    pub const unknown_val = 0;

    pub const init: DisplayTile = .{
        .entity = unknown_val,
        .item = unknown_val,
        .floor = unknown_val,
        .visible = false,
    };
};

// NOTE: There's some testing of MapTile in roguelib

// EOF
