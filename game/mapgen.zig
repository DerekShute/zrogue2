//!
//! Rogue-specific mapgen utility functions
//!
//! REFACTOR: look at use cases and define more efficient API
//!

const std = @import("std");
const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;
const Room = @import("roguelib").Room;

//
// Configuration
//

pub const XSIZE = 80; // Traditional dimensions
pub const YSIZE = 24;

//
// Types
//

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

    pub fn fromTile(self: Tile) MapTile {
        return @enumFromInt(@intFromEnum(self));
    }
};

//
// Lifecycle
//

pub const Config = struct {
    level: u16 = undefined,
    going_down: bool = undefined,

    pub const init = Config{
        .level = 1,
        .going_down = true,
    };
};

pub fn create(allocator: std.mem.Allocator, xrooms: i16, yrooms: i16) !*Map {
    const map = try Map.init(allocator, XSIZE, YSIZE, xrooms, yrooms);
    drawField(map, .init(0, 0), .init(XSIZE - 1, YSIZE - 1), .wall);
    return map;
}

//
// Utility Functions
//
// NOTE: assumes a corridor: dark and passable
fn drawHorizLine(m: *Map, start: Pos, end_x: Pos.Dim) void {
    const minx = @min(start.getX(), end_x + 1);
    const maxx = @max(start.getX(), end_x + 1);
    for (@intCast(minx)..@intCast(maxx)) |x| {
        setFloor(m, .init(@intCast(x), start.getY()), .corridor);
    }
}

fn drawVertLine(m: *Map, start: Pos, end_y: Pos.Dim) void {
    const miny = @min(start.getY(), end_y + 1);
    const maxy = @max(start.getY(), end_y + 1);
    for (@intCast(miny)..@intCast(maxy)) |y| {
        setFloor(m, .init(start.getX(), @intCast(y)), .corridor);
    }
}

fn drawField(m: *Map, start: Pos, limit: Pos, tile: MapTile) void {
    // assumes start.x <= limit.x and start.y <= limit.y
    var r = Region.config(start, limit);
    var ri = r.iterator();
    while (ri.next()) |pos| {
        setFloor(m, pos, tile);
    }
}

fn setLit(m: *Map, region: Region, lit: bool) void {
    var _r = region; // Slide out of const
    var i = _r.iterator();
    while (i.next()) |pos| {
        m.setLit(pos, lit);
    }
}

//
// Entities
//

pub fn addEntityToMap(m: *Map, e: *Entity, p: Pos) void {
    e.setPos(p);
    m.addEntity(e, p);
}

// Features

pub const Feature = enum {
    trap,
    secret_door,
    // FUTURE: stairs down, stairs up
    // FUTURE: illusionary wall, hidden treasure
};

pub fn addSecretDoor(m: *Map, p: Pos) void {
    setFloor(m, p, .wall);
    m.setFeature(p, @intFromEnum(Feature.secret_door));
}

pub fn addTrap(m: *Map, p: Pos) void {
    setFloor(m, p, .floor);
    m.setFeature(p, @intFromEnum(Feature.trap));
}

// Floor

pub fn getFloor(map: *Map, pos: Pos) MapTile {
    return .fromTile(map.getFloor(pos));
}

pub fn setFloor(map: *Map, pos: Pos, floor: MapTile) void {
    // NOTE: assumes only wall is nonpassable
    map.setFloor(pos, .fromOther(floor));
    map.setPassable(pos, (floor != .wall));
}

//
// Items
//
// TODO: MapTile becomes identifier

pub fn addItem(m: *Map, p: Pos, t: MapTile) void {
    m.setItem(p, .fromOther(t));
}

pub fn getItem(m: *Map, p: Pos) MapTile {
    return .fromTile(m.getItem(p));
}

//
// Rooms
//

// Rectangular room that includes the bounding walls
pub fn addRoom(m: *Map, room: Room) void {
    var _r = room; // slide to non-const
    m.addRoom(_r);

    // Floor boundaries
    const s = Pos.init(_r.getMinX() + 1, _r.getMinY() + 1);
    const e = Pos.init(_r.getMaxX() - 1, _r.getMaxY() - 1);

    // source and end are known good because we added the room above
    drawField(m, s, e, .floor);

    if (_r.isLit()) {
        setLit(m, _r.getRegion(), true);
    }
}

//
// Corridors
//

// Basically-southgoing corridor
pub fn addSouthCorridor(
    map: *Map,
    start: Pos,
    end: Pos,
    mid: Pos.Dim, // Cross corridor location
) void {
    drawVertLine(map, start, mid);
    drawHorizLine(map, .init(start.getX(), mid), end.getX());
    drawVertLine(map, .init(end.getX(), mid), end.getY());
}

// Basically-eastgoing corridor
pub fn addEastCorridor(
    map: *Map,
    start: Pos,
    end: Pos,
    mid: Pos.Dim,
) void {
    drawHorizLine(map, start, mid);
    drawVertLine(map, .init(mid, start.getY()), end.getY());
    drawHorizLine(map, .init(mid, end.getY()), end.getX());
}

//
// Unit tests
//

const expect = std.testing.expect;
const Tile = @import("common").Tile;

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
    }
}

test "mapgen smoke test" {
    var m = try create(std.testing.allocator, 1, 1);
    defer m.deinit(std.testing.allocator);

    const r = Room.config(.init(10, 10), .init(20, 20));
    addRoom(m, r);

    try expect(m.isLit(.init(15, 15)) == true);
    try expect(m.isPassable(.init(15, 15)) == true);

    try expect(getFloor(m, .init(0, 0)) == .wall);
    try expect(getFloor(m, .init(10, 10)) == .wall);
    try expect(m.isPassable(.init(10, 10)) == false);

    // Explicit set tile inside a known room
    setFloor(m, .init(17, 17), .wall);
    try expect(getFloor(m, .init(17, 17)) == .wall);

    setFloor(m, .init(18, 18), .door);
    try expect(getFloor(m, .init(18, 18)) == .door);
    try expect(m.isPassable(.init(18, 18)) == true);

    addItem(m, .init(16, 16), .gold);
    try expect(getItem(m, .init(16, 16)) == .gold);
    addItem(m, .init(16, 16), .unknown);
    try expect(getItem(m, .init(16, 16)) == .unknown);
}

// Corridors

test "dig corridors" {
    var m = try create(std.testing.allocator, 2, 2);
    defer m.deinit(std.testing.allocator);

    // These don't have to make sense as part of actual rooms
    // Doors are created by the level generator

    // Eastward dig, southgoing vertical
    addEastCorridor(m, .init(4, 4), .init(20, 10), 12);
    try expect(getFloor(m, .init(12, 7)) == .corridor); // halfway
    try expect(m.isLit(.init(12, 7)) == false);
    try expect(m.isPassable(.init(12, 7)) == true);
    try expect(getFloor(m, .init(12, 4)) == .corridor);
    try expect(getFloor(m, .init(12, 10)) == .corridor);
    try expect(getFloor(m, .init(4, 4)) == .corridor);
    try expect(getFloor(m, .init(20, 10)) == .corridor);

    drawField(m, .init(4, 4), .init(20, 10), .wall); // reset

    // Eastward dig, northgoing vertical
    addEastCorridor(m, .init(4, 10), .init(20, 4), 12);
    try expect(getFloor(m, .init(12, 7)) == .corridor); // halfway
    try expect(m.isLit(.init(12, 7)) == false);
    try expect(m.isPassable(.init(12, 7)) == true);

    try expect(getFloor(m, .init(12, 4)) == .corridor);
    try expect(getFloor(m, .init(12, 10)) == .corridor);
    try expect(getFloor(m, .init(4, 10)) == .corridor);
    try expect(getFloor(m, .init(20, 4)) == .corridor);

    drawField(m, .init(4, 4), .init(20, 10), .wall); // reset

    // Southward dig, westgoing horizontal
    addSouthCorridor(m, .init(10, 8), .init(3, 14), 11);
    try expect(getFloor(m, .init(6, 11)) == .corridor); // halfway
    try expect(m.isPassable(.init(6, 11)) == true);

    try expect(getFloor(m, .init(3, 11)) == .corridor);
    try expect(getFloor(m, .init(10, 11)) == .corridor);
    try expect(getFloor(m, .init(10, 8)) == .corridor);
    try expect(getFloor(m, .init(3, 14)) == .corridor);

    drawField(m, .init(3, 8), .init(10, 14), .wall); // reset

    // Southward dig, eastgoing horizontal
    addSouthCorridor(m, .init(3, 8), .init(10, 14), 11);
    try expect(getFloor(m, .init(6, 11)) == .corridor); // halfway
    try expect(m.isPassable(.init(6, 11)) == true);

    try expect(getFloor(m, .init(3, 11)) == .corridor);
    try expect(getFloor(m, .init(10, 11)) == .corridor);
    try expect(getFloor(m, .init(3, 8)) == .corridor);
    try expect(getFloor(m, .init(10, 14)) == .corridor);

    drawField(m, .init(3, 8), .init(10, 14), .wall); // reset
}

test "dig unusual corridors" {
    var m = try create(std.testing.allocator, 2, 2);
    defer m.deinit(std.testing.allocator);

    // One tile
    addSouthCorridor(m, .init(5, 10), .init(5, 12), 11);
    try expect(getFloor(m, .init(5, 11)) == .corridor);

    // straight East
    addEastCorridor(m, .init(10, 5), .init(15, 5), 12);
    try expect(getFloor(m, .init(11, 5)) == .corridor);
    try expect(getFloor(m, .init(13, 5)) == .corridor);
    try expect(getFloor(m, .init(14, 5)) == .corridor);

    // straight South
    addSouthCorridor(m, .init(16, 8), .init(16, 13), 10);
    try expect(getFloor(m, .init(16, 9)) == .corridor);
    try expect(getFloor(m, .init(16, 10)) == .corridor);
    try expect(getFloor(m, .init(16, 12)) == .corridor);
}

// EOF
