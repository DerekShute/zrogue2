//!
//! Mapgen common utilities for mapgen algorithms
//!

const std = @import("std");
const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const MapTile = @import("roguelib").MapTile;
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;
const Room = @import("roguelib").Room;

//
// Map Configuration
//

pub const Config = struct {
    player: ?*Entity = null,
    xSize: Pos.Dim = -1,
    ySize: Pos.Dim = -1,
    level: usize = 1,
    going_down: bool = true,
    mapgen: enum {
        TEST,
    },
};

//
// Utility Functions
//

pub fn drawHorizLine(m: *Map, start: Pos, end_x: Pos.Dim, tile: MapTile) void {
    const minx = @min(start.getX(), end_x + 1);
    const maxx = @max(start.getX(), end_x + 1);
    for (@intCast(minx)..@intCast(maxx)) |x| {
        m.setTile(Pos.config(@intCast(x), start.getY()), tile);
    }
}

pub fn drawVertLine(m: *Map, start: Pos, end_y: Pos.Dim, tile: MapTile) void {
    const miny = @min(start.getY(), end_y + 1);
    const maxy = @max(start.getY(), end_y + 1);
    for (@intCast(miny)..@intCast(maxy)) |y| {
        m.setTile(Pos.config(start.getX(), @intCast(y)), tile);
    }
}

pub fn drawField(m: *Map, start: Pos, limit: Pos, tile: MapTile) void {
    // assumes start.x <= limit.x and start.y <= limit.y
    var r = Region.config(start, limit);
    var ri = r.iterator();
    while (ri.next()) |pos| {
        m.setTile(pos, tile);
    }
}

// Entities

pub fn addEntityToMap(m: *Map, e: *Entity, p: Pos) void {
    e.setPos(p);
    m.addEntity(e, p);
}

// Rooms

pub fn addRoom(m: *Map, room: Room) void {
    var r = room; // slide to non-const
    m.addRoom(r);

    // The original drew horizontal and vertical bars
    // Fns.vert(map, minx, .{ miny + 1, maxy - 1 });
    // Fns.vert(map, maxx, .{ miny + 1, maxy - 1 });
    // Fns.horiz(map, miny, .{ minx, maxx });
    // Fns.horiz(map, maxy, .{ minx, maxx });

    // Floor

    const s = Pos.config(r.getMinX() + 1, r.getMinY() + 1);
    const e = Pos.config(r.getMaxX() - 1, r.getMaxY() - 1);

    // TODO Future: room shapes and contents

    // source and end are known good because we added the room above

    drawField(m, s, e, .floor);
}

pub fn getRoom(m: *Map, roomno: usize) *Room {
    // Slightly better than using the raw reference
    if (roomno >= m.rooms.len) {
        @panic("mapgen.getRoom bad room number");
    }
    return &m.rooms[roomno];
}

// Corridors

pub fn addSouthCorridor(m: *Map, start: Pos, end: Pos, mid: Pos.Dim) void {
    // FIXME: the start and end should be validated
    drawVertLine(m, start, mid, .floor);
    drawHorizLine(m, Pos.config(start.getX(), mid), end.getX(), .floor);
    drawVertLine(m, Pos.config(end.getX(), mid), end.getY(), .floor);
}

pub fn addEastCorridor(m: *Map, start: Pos, end: Pos, mid: Pos.Dim) void {
    // FIXME: the start and end should be validated
    drawHorizLine(m, start, mid, .floor);
    drawVertLine(m, Pos.config(mid, start.getY()), end.getY(), .floor);
    drawHorizLine(m, Pos.config(mid, end.getY()), end.getX(), .floor);
}

// TODO: common functions...
// * locate a place for a door
// * draw a maze

//
// Unit tests
//

const expect = std.testing.expect;

test "mapgen smoke test" {
    var m = try Map.init(std.testing.allocator, 100, 50, 1, 1);
    defer m.deinit(std.testing.allocator);

    const r = Room.config(Pos.config(10, 10), Pos.config(20, 20));
    addRoom(m, r);

    try expect(m.isLit(Pos.config(15, 15)) == true);

    try expect(m.getFloorTile(Pos.config(0, 0)) == .wall);
    try expect(m.getFloorTile(Pos.config(10, 10)) == .wall);

    // Explicit set tile inside a known room
    m.setTile(Pos.config(17, 17), .wall);
    try expect(m.getFloorTile(Pos.config(17, 17)) == .wall);

    m.setTile(Pos.config(18, 18), .door);
    try expect(m.getFloorTile(Pos.config(18, 18)) == .door);
}

// Corridors

test "dig corridors" {
    var m = try Map.init(std.testing.allocator, 40, 40, 2, 2);
    defer m.deinit(std.testing.allocator);

    // These don't have to make sense as part of actual rooms
    // Doors are created by the level generator

    // Eastward dig, southgoing vertical
    addEastCorridor(m, Pos.config(4, 4), Pos.config(20, 10), 12);
    try expect(m.getFloorTile(Pos.config(12, 7)) == .floor); // halfway
    try expect(m.getFloorTile(Pos.config(12, 4)) == .floor);
    try expect(m.getFloorTile(Pos.config(12, 10)) == .floor);
    try expect(m.getFloorTile(Pos.config(4, 4)) == .floor);
    try expect(m.getFloorTile(Pos.config(20, 10)) == .floor);
    drawField(m, Pos.config(4, 4), Pos.config(20, 10), .wall); // reset

    // Eastward dig, northgoing vertical
    addEastCorridor(m, Pos.config(4, 10), Pos.config(20, 4), 12);
    try expect(m.getFloorTile(Pos.config(12, 7)) == .floor); // halfway
    try expect(m.getFloorTile(Pos.config(12, 4)) == .floor);
    try expect(m.getFloorTile(Pos.config(12, 10)) == .floor);
    try expect(m.getFloorTile(Pos.config(4, 10)) == .floor);
    try expect(m.getFloorTile(Pos.config(20, 4)) == .floor);
    drawField(m, Pos.config(4, 4), Pos.config(20, 10), .wall); // reset

    // Southward dig, westgoing horizontal
    addSouthCorridor(m, Pos.config(10, 8), Pos.config(3, 14), 11);
    try expect(m.getFloorTile(Pos.config(6, 11)) == .floor); // halfway
    try expect(m.getFloorTile(Pos.config(3, 11)) == .floor);
    try expect(m.getFloorTile(Pos.config(10, 11)) == .floor);
    try expect(m.getFloorTile(Pos.config(10, 8)) == .floor);
    try expect(m.getFloorTile(Pos.config(3, 14)) == .floor);
    drawField(m, Pos.config(3, 8), Pos.config(10, 14), .wall); // reset

    // Southward dig, eastgoing horizontal
    addSouthCorridor(m, Pos.config(3, 8), Pos.config(10, 14), 11);
    try expect(m.getFloorTile(Pos.config(6, 11)) == .floor); // halfway
    try expect(m.getFloorTile(Pos.config(3, 11)) == .floor);
    try expect(m.getFloorTile(Pos.config(10, 11)) == .floor);
    try expect(m.getFloorTile(Pos.config(3, 8)) == .floor);
    try expect(m.getFloorTile(Pos.config(10, 14)) == .floor);
    drawField(m, Pos.config(3, 8), Pos.config(10, 14), .wall); // reset
}

test "dig unusual corridors" {
    var m = try Map.init(std.testing.allocator, 20, 20, 2, 2);
    defer m.deinit(std.testing.allocator);

    // One tile
    addSouthCorridor(m, Pos.config(5, 10), Pos.config(5, 12), 11);
    try expect(m.getFloorTile(Pos.config(5, 11)) == .floor);

    // straight East
    addEastCorridor(m, Pos.config(10, 5), Pos.config(15, 5), 12);
    try expect(m.getFloorTile(Pos.config(11, 5)) == .floor);
    try expect(m.getFloorTile(Pos.config(13, 5)) == .floor);
    try expect(m.getFloorTile(Pos.config(14, 5)) == .floor);

    // straight South
    addSouthCorridor(m, Pos.config(16, 8), Pos.config(16, 13), 10);
    try expect(m.getFloorTile(Pos.config(16, 9)) == .floor);
    try expect(m.getFloorTile(Pos.config(16, 10)) == .floor);
    try expect(m.getFloorTile(Pos.config(16, 12)) == .floor);
}

// EOF
