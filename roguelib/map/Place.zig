//!
//! Spot on the map and everything on it
//!

const Entity = @import("../Entity.zig");
const MapTile = @import("common").MapTile; // TODO for now
const Tile = @import("common").Tile;
const Tileset = @import("Tileset.zig");

const Self = @This();

// TODO: shameful
const WALL: Tile = .fromOther(MapTile.wall);

//
// Members
//

entity: ?*Entity = undefined, // FUTURE: reference
feature: ?u8 = undefined,
floor: Tile = undefined,
item: Tile = undefined, // FUTURE: Item reference
lit: bool = undefined,
passable: bool = undefined,

//
// Constructor, probably not idiomatic
//

pub const init: Self = .{
    .entity = null,
    .feature = null,
    .floor = WALL,
    .item = .init,

    // FUTURE: packed u8, Game-controlled fields and state

    .lit = false,
    .passable = false,
};

//
// Methods
//

pub fn getTileset(self: *Self) Tileset {
    return .{
        .floor = self.floor,
        .entity = self.getEntityTile(),
        .item = self.item,
    };
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

fn getEntityTile(self: *Self) Tile {
    if (self.entity) |e| {
        return e.getTile();
    }
    return .none;
}

// Items

pub fn getItem(self: *Self) Tile {
    return self.item;
}

pub fn setItem(self: *Self, to: Tile) void {
    if ((to != .none) and (self.item != .none)) {
        @panic("Place.setItem: already in use\n");
    }
    self.item = to;
}

// Floor

pub fn getFloor(self: *Self) Tile {
    return self.floor;
}

pub fn setFloor(self: *Self, to: Tile) void {
    self.floor = to;
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

    place.setFloor(@enumFromInt(4));
    const ts = place.getTileset();
    try expect(@intFromEnum(ts.floor) == 4);
    try expect(ts.entity == .none);
    try expect(ts.item == .none);
    try expect(place.isPassable() == false);
    try expect(place.feature == null);

    try expect(place.isLit() == false);
    place.setLit(true);
    try expect(place.isLit() == true);

    try expect(place.isPassable() == false);
    place.setPassable(true);
    try expect(place.isPassable() == true);

    const t: Tile = @enumFromInt(5);
    place.setItem(t);
    try expect(place.getItem() == t);
    place.setItem(.none); // Must be allowed; any other set will panic
    place.setItem(t);
}

// EOF
