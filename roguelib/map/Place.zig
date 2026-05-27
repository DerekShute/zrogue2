//!
//! Spot on the map and everything on it
//!

const Entity = @import("../Entity.zig");
const Feature = @import("../Feature.zig");
const Tile = @import("common").Tile;
const Tileset = @import("../Tileset.zig");
const MapTile = Tileset.MapTile;

const Self = @This();

//
// Members
//

entity: ?*Entity = undefined,
feature: ?u8 = undefined,
floor: Tile = undefined,
item: Tile = undefined, // FUTURE: Item type
lit: bool = undefined,
// TODO: passable explicit bool

//
// Constructor, probably not idiomatic
//

pub const init: Self = .{
    .entity = null,
    .feature = null,
    .floor = .fromOther(MapTile.wall), // TODO: Map default, should be explicit
    .item = .init,
    .lit = false,
};

//
// Methods
//

pub fn getTileset(self: *Self) Tileset {
    var ts: Tileset = .{
        .floor = .fromTile(self.floor),
        .entity = .unknown,
        .item = .fromTile(self.item),
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
    self.entity = null;
}

pub fn setItem(self: *Self, to: MapTile) void {
    if (self.item != .none) {
        @panic("Place.setItem: already in use\n");
    }
    self.item = .fromOther(to);
}

pub fn getItem(self: *Self) MapTile {
    return .fromTile(self.item);
}

pub fn removeItem(self: *Self) void {
    self.item = .none;
}

pub fn setFloorTile(self: *Self, to: MapTile) void {
    self.floor = .fromOther(to);
}

// Features

pub fn setFeature(self: *Self, to: ?u8) void {
    self.feature = to;
}

pub fn getFeature(self: *Self) ?u8 {
    return self.feature;
}

// FUTURE: as a bool

pub fn passable(self: *Self) bool {
    if (self.entity) |_| {
        return false;
    }
    const floor = MapTile.fromTile(self.floor);
    return floor.isPassable();
}

// Flags (lit)

pub fn isLit(self: *Self) bool {
    return self.lit;
}

pub fn setLit(self: *Self, val: bool) void {
    self.lit = val;
}

//
// Unit Tests
//

const expect = @import("std").testing.expect;

test "basic tests" {
    var place: Self = .init;

    place.setFloorTile(.wall);
    const ts = place.getTileset();
    try expect(ts.floor == .wall);
    try expect(ts.entity == .unknown);
    try expect(ts.item == .unknown);
    try expect(place.passable() == false);
    try expect(place.feature == null);

    try expect(place.isLit() == false);
    place.setLit(true);
    try expect(place.isLit() == true);
}

// EOF
