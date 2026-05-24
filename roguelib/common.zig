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

// TODO: This is Rogue-specific
pub const MapTile = enum(u8) {
    unknown,
    floor,
    corridor,
    wall, // Start of features
    trap, // visible trap
    door,
    stairs_down,
    stairs_up, // Last feature
    gold,
    player,

    pub const init = .unknown;

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

    pub fn fromTile(self: Tile) MapTile {
        return @enumFromInt(@intFromEnum(self));
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

//
// Unit Tests
//

const std = @import("std");
const expect = std.testing.expect;

test "lock MapTile and Tile assumptions" {
    // Just a base assumption

    try expect(@intFromEnum(MapTile.unknown) == @intFromEnum(Tile.none));
}

test "lock MapTile behavior" {
    for (0..@typeInfo(MapTile).@"enum".fields.len) |i| {
        const tile: MapTile = @enumFromInt(i);

        // Floors and unknown are not features.  Otherwise everything below
        // gold is.

        switch (tile) {
            .unknown, .floor, .corridor => try expect(tile.isFeature() == false),
            else => {
                try expect(tile.isFeature() == (i < @intFromEnum(MapTile.gold)));
            },
        }

        // Walls and undiscovered secret doors are not passable.
        // .unknown is unclear
        const passable = (i != @intFromEnum(MapTile.wall));
        try expect(tile.isPassable() == passable);
    }
}

// EOF
