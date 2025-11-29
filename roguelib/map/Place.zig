//!
//! Spot on the map and everything on it
//!

const MapTile = @import("../maptile.zig").MapTile;

const Self = @This();

//
// Members
//

tile: MapTile = .unknown,
// TODO entity
// TODO item
// TODO feature

//
// Constructor, probably not idiomatic
//

// TODO probably not
pub fn config(self: *Self) void {
    self.tile = .wall;
}

//
// Methods
//

pub fn getTile(self: *Self) MapTile {
    return self.tile;
}

pub fn passable(self: *Self) bool {
    return self.tile.isPassable();
}

pub fn setTile(self: *Self, to: MapTile) void {
    self.tile = to;
}

//
// Unit Tests
//

const expect = @import("std").testing.expect;

test "basic tests" {
    var place: Self = .{};

    place.setTile(.wall);
    try expect(place.getTile() == .wall);
    try expect(place.passable() == false);
}

// EOF
