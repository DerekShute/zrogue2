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
// Map Tiles
//

// Abstract Tile (internal to library)
pub const Tile = enum(u8) {
    none,
    _,

    pub const init: Tile = .none;

    // argument must be an enum u8
    pub fn fromOther(tile: anytype) Tile {
        return @enumFromInt(@intFromEnum(tile));
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

// EOF
