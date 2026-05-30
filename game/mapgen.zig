//!
//! Rogue-specific mapgen utility functions
//!
//! REFACTOR: look at use cases and define more efficient API
//!

const std = @import("std");
const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const MapTile = @import("common").MapTile;
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;
const Room = @import("roguelib").Room;

//
// Utility Functions
//
// NOTE: assumes a corridor: dark and passable
fn drawHorizLine(m: *Map, start: Pos, end_x: Pos.Dim, tile: MapTile) void {
    const minx = @min(start.getX(), end_x + 1);
    const maxx = @max(start.getX(), end_x + 1);
    for (@intCast(minx)..@intCast(maxx)) |x| {
        const p = Pos.init(@intCast(x), start.getY());
        setFloor(m, p, tile);
    }
}

fn drawVertLine(m: *Map, start: Pos, end_y: Pos.Dim, tile: MapTile) void {
    const miny = @min(start.getY(), end_y + 1);
    const maxy = @max(start.getY(), end_y + 1);
    for (@intCast(miny)..@intCast(maxy)) |y| {
        const p = Pos.init(start.getX(), @intCast(y));
        setFloor(m, p, tile);
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
//
// REFACTOR: back to .floor
pub fn addRoom(m: *Map, room: Room, floor: MapTile) void {
    var _r = room; // slide to non-const
    m.addRoom(_r);

    // Floor boundaries
    const s = Pos.init(_r.getMinX() + 1, _r.getMinY() + 1);
    const e = Pos.init(_r.getMaxX() - 1, _r.getMaxY() - 1);

    // source and end are known good because we added the room above
    drawField(m, s, e, floor);

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
    floor: MapTile,
) void {
    drawVertLine(map, start, mid, floor);
    drawHorizLine(map, .init(start.getX(), mid), end.getX(), floor);
    drawVertLine(map, .init(end.getX(), mid), end.getY(), floor);
}

// Basically-eastgoing corridor
pub fn addEastCorridor(
    map: *Map,
    start: Pos,
    end: Pos,
    mid: Pos.Dim,
    floor: MapTile,
) void {
    drawHorizLine(map, start, mid, floor);
    drawVertLine(map, .init(mid, start.getY()), end.getY(), floor);
    drawHorizLine(map, .init(mid, end.getY()), end.getX(), floor);
}

//
// Unit tests
//

const expect = std.testing.expect;

test "mapgen smoke test" {
    var m = try Map.init(std.testing.allocator, 100, 50, 1, 1);
    defer m.deinit(std.testing.allocator);

    const r = Room.config(.init(10, 10), .init(20, 20));
    addRoom(m, r, .floor);

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
    var m = try Map.init(std.testing.allocator, 40, 40, 2, 2);
    defer m.deinit(std.testing.allocator);

    // These don't have to make sense as part of actual rooms
    // Doors are created by the level generator

    // Eastward dig, southgoing vertical
    addEastCorridor(m, .init(4, 4), .init(20, 10), 12, .floor);
    try expect(getFloor(m, .init(12, 7)) == .floor); // halfway
    try expect(m.isLit(.init(12, 7)) == false);
    try expect(m.isPassable(.init(12, 7)) == true);
    try expect(getFloor(m, .init(12, 4)) == .floor);
    try expect(getFloor(m, .init(12, 10)) == .floor);
    try expect(getFloor(m, .init(4, 4)) == .floor);
    try expect(getFloor(m, .init(20, 10)) == .floor);

    drawField(m, .init(4, 4), .init(20, 10), .wall); // reset

    // Eastward dig, northgoing vertical
    addEastCorridor(m, .init(4, 10), .init(20, 4), 12, .floor);
    try expect(getFloor(m, .init(12, 7)) == .floor); // halfway
    try expect(m.isLit(.init(12, 7)) == false);
    try expect(m.isPassable(.init(12, 7)) == true);

    try expect(getFloor(m, .init(12, 4)) == .floor);
    try expect(getFloor(m, .init(12, 10)) == .floor);
    try expect(getFloor(m, .init(4, 10)) == .floor);
    try expect(getFloor(m, .init(20, 4)) == .floor);

    drawField(m, .init(4, 4), .init(20, 10), .wall); // reset

    // Southward dig, westgoing horizontal
    addSouthCorridor(m, .init(10, 8), .init(3, 14), 11, .floor);
    try expect(getFloor(m, .init(6, 11)) == .floor); // halfway
    try expect(m.isPassable(.init(6, 11)) == true);

    try expect(getFloor(m, .init(3, 11)) == .floor);
    try expect(getFloor(m, .init(10, 11)) == .floor);
    try expect(getFloor(m, .init(10, 8)) == .floor);
    try expect(getFloor(m, .init(3, 14)) == .floor);

    drawField(m, .init(3, 8), .init(10, 14), .wall); // reset

    // Southward dig, eastgoing horizontal
    addSouthCorridor(m, .init(3, 8), .init(10, 14), 11, .floor);
    try expect(getFloor(m, .init(6, 11)) == .floor); // halfway
    try expect(m.isPassable(.init(6, 11)) == true);

    try expect(getFloor(m, .init(3, 11)) == .floor);
    try expect(getFloor(m, .init(10, 11)) == .floor);
    try expect(getFloor(m, .init(3, 8)) == .floor);
    try expect(getFloor(m, .init(10, 14)) == .floor);

    drawField(m, .init(3, 8), .init(10, 14), .wall); // reset
}

test "dig unusual corridors" {
    var m = try Map.init(std.testing.allocator, 20, 20, 2, 2);
    defer m.deinit(std.testing.allocator);

    // One tile
    addSouthCorridor(m, .init(5, 10), .init(5, 12), 11, .floor);
    try expect(getFloor(m, .init(5, 11)) == .floor);

    // straight East
    addEastCorridor(m, .init(10, 5), .init(15, 5), 12, .floor);
    try expect(getFloor(m, .init(11, 5)) == .floor);
    try expect(getFloor(m, .init(13, 5)) == .floor);
    try expect(getFloor(m, .init(14, 5)) == .floor);

    // straight South
    addSouthCorridor(m, .init(16, 8), .init(16, 13), 10, .floor);
    try expect(getFloor(m, .init(16, 9)) == .floor);
    try expect(getFloor(m, .init(16, 10)) == .floor);
    try expect(getFloor(m, .init(16, 12)) == .floor);
}

// EOF
