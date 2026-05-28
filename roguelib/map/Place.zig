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
passable: bool = undefined,

//
// Constructor, probably not idiomatic
//

pub const init: Self = .{
    .entity = null,
    .feature = null,
    .floor = .fromOther(MapTile.wall), // TODO: Map default, should be explicit
    .item = .init,

    // FUTURE: packed u8, Game-controlled fields and state

    .lit = false,
    .passable = false,
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

// FUTURE: an index that is Game controlled

pub fn setEntity(self: *Self, to: *Entity) void {
    if (self.entity) |_| {
        @panic("Place.setEntity: already in use\n");
    }
    self.entity = to;
}

pub fn removeEntity(self: *Self) void {
    self.entity = null;
}

// FUTURE: an index/ID that is Game controlled

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

// Floor

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

// Flags (lit, passable)

pub fn isLit(self: *Self) bool {
    return self.lit;
}

pub fn setLit(self: *Self, val: bool) void {
    self.lit = val;
}

pub fn isPassable(self: *Self) bool {
    return self.passable;
}

pub fn setPassable(self: *Self, val: bool) void {
    self.passable = val;
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
    try expect(place.isPassable() == false);
    try expect(place.feature == null);

    try expect(place.isLit() == false);
    place.setLit(true);
    try expect(place.isLit() == true);

    try expect(place.isPassable() == false);
    place.setPassable(true);
    try expect(place.isPassable() == true);
}

// EOF
