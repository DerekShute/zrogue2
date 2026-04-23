//!
//! Visible thing at map space
//!

const std = @import("std");
pub const MapTile = @import("rogueui").MapTile;

// TODO: these are all game and level gen concepts
pub const Feature = enum {
    none,
    trap,
    door,
    secret_door,
    stairs_down,
    stairs_up,
};

//
// Tileset - tiles at a location (floor, entity, feature)
//
// TODO: consolidate on ui Tile, which is general

pub const Tileset = struct {
    floor: MapTile,
    entity: MapTile,
    item: MapTile,
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

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Tileset);

// EOF
