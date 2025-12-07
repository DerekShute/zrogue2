//!
//! Visible thing at map space
//!

// TODO Future: union with monster types and objects?

const std = @import("std");

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
// Tileset - tiles at a location (floor, entity, feature)
//

pub const Tileset = struct {
    floor: MapTile,
    entity: MapTile,
};

//
// Unit Tests
//
const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "lock MapTile behavior" {
    for (0..@typeInfo(MapTile).@"enum".fields.len) |i| {
        const tile: MapTile = @enumFromInt(i);

        // Floors and unknown are not features.  Otherwise everything below
        // gold is.

        switch (tile) {
            .unknown, .floor => try expect(tile.isFeature() == false),
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
