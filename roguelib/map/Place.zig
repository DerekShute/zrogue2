//!
//! Spot on the map and everything on it
//!

const Entity = @import("../Entity.zig");
const MapTile = @import("../maptile.zig").MapTile;
const Tileset = @import("../maptile.zig").Tileset;

const Self = @This();

//
// Members
//

floor: MapTile = .unknown,
entity: ?*Entity = null,
// TODO item
// TODO feature

//
// Constructor, probably not idiomatic
//

// TODO probably not
pub fn config(self: *Self) void {
    self.floor = .wall;
    self.entity = null;
}

//
// Methods
//

pub fn getTileset(self: *Self) Tileset {
    var ts: Tileset = .{
        .floor = self.floor,
        .entity = .unknown,
    };

    if (self.entity) |e| {
        ts.entity = e.getTile();
    }

    return ts;
}

pub fn setEntity(self: *Self, to: *Entity) void {
    if (self.entity) |_| {
        @panic("Place.setEntity: already in use\n");
    }
    self.entity = to;
}

pub fn removeEntity(self: *Self) void {
    // TODO: validate that there is one?
    self.entity = null;
}

pub fn setFloorTile(self: *Self, to: MapTile) void {
    self.floor = to;
}

pub fn passable(self: *Self) bool {
    if (self.entity) |_| {
        return false;
    }
    return self.floor.isPassable();
}

//
// Unit Tests
//

const expect = @import("std").testing.expect;

// Need mock Entity to test

test "basic tests" {
    var place: Self = .{};

    place.setFloorTile(.wall);
    const ts = place.getTileset();
    try expect(ts.floor == .wall);
    try expect(place.passable() == false);
}

// EOF
