//!
//! Generating a map with the rogue style
//!

const std = @import("std");

const Map = @import("roguelib").Map;
const mapgen = @import("roguelib").mapgen;
const MapTile = @import("roguelib").MapTile;
const Player = @import("Player.zig");
const Pos = @import("roguelib").Pos;
const Room = @import("roguelib").Room;

//
// Constants that this mapgen relies on
//

const min_room_dim = 4; // min non-gone room size: 2x2 not including walls
const rooms_dim = 3; // 3x3 grid of room 'spots'
const max_rooms = rooms_dim * rooms_dim;
const map_xsize = 80;
const map_ysize = 24;

//
// Types
//

pub const Config = struct {
    rand: *std.Random = undefined,
    level: u16 = 1,
    going_down: bool = true,
};

//
// Utilities
//

fn makeGoneRoom(roomno: i16, map: *Map, r: *std.Random) Room {
    // Calling it a 3x3 box
    const max_xsize = @divTrunc(map.getWidth(), rooms_dim);
    const max_ysize = @divTrunc(map.getHeight(), rooms_dim);
    const topx = @mod(roomno, rooms_dim) * max_xsize;
    const topy = @divTrunc(roomno, rooms_dim) * max_ysize;

    // Prevent anything from taking column 79 or row 23
    // the original has just this sort of hack: retry until it fits

    var done = false;
    var room: Room = undefined;
    while (!done) {
        // gone rooms are 3x3 and East/South edge border is reserved
        // for possible corridor
        const xpos = topx + r.intRangeAtMost(Pos.Dim, 0, max_xsize - 4);
        const ypos = topy + r.intRangeAtMost(Pos.Dim, 0, max_ysize - 4);

        // Need to leave column 79 and row 23 as wall
        if ((xpos < map.getWidth() - 3) and (ypos < map.getHeight() - 3)) {
            const tl = Pos.config(xpos, ypos);
            const br = Pos.config(xpos + 2, ypos + 2);
            room = Room.config(tl, br);
            done = true;
        }
    }

    room.setDark();
    room.setGone();
    return room;
}

fn makeRoom(roomno: i16, map: *Map, r: *std.Random) Room {
    // Size of bounding box and its upper left corner
    const max_xsize = @divTrunc(map.getWidth(), rooms_dim);
    const max_ysize = @divTrunc(map.getHeight(), rooms_dim);
    const topx = @mod(roomno, rooms_dim) * max_xsize;
    const topy = @divTrunc(roomno, rooms_dim) * max_ysize;

    // FUTURE : maze

    // The room size must leave one block on the East and South edges for
    // corridors, and this must be reflected in the positioning logic, so
    // always max_#size - 1
    //
    // Also prevent anything from taking column 79 or row 23

    // the original has just this sort of hack: retry until it fits
    var done = false;
    var room: Room = undefined;
    while (!done) {
        const xlen = r.intRangeAtMost(Pos.Dim, min_room_dim, max_xsize - 1);
        const ylen = r.intRangeAtMost(Pos.Dim, min_room_dim, max_ysize - 1);
        const xpos = topx + r.intRangeAtMost(Pos.Dim, 0, max_xsize - 1 - xlen);
        const ypos = topy + r.intRangeAtMost(Pos.Dim, 0, max_ysize - 1 - ylen);

        const endx = xpos + xlen - 1;
        const endy = ypos + ylen - 1;
        if ((endx < map.getWidth() - 2) and (endy < map.getHeight() - 2)) {
            const tl = Pos.config(xpos, ypos);
            const br = Pos.config(endx, endy);
            room = Room.config(tl, br);
            done = true;
        }
    }

    if (r.intRangeAtMost(usize, 1, 10) < map.level) {
        room.setDark();
        // TODO Future: maze (1 in 15)
    }

    return room;
}

fn makeDoor(map: *Map, r: *std.Random, p: Pos) void {
    // Original goes
    //
    //     if (rnd(10) + 1 < level && rnd(5) == 0) then secret door

    map.setFloorTile(p, .door);
    if ((r.intRangeAtMost(u16, 1, 10) < map.level) and (r.intRangeAtMost(u16, 0, 4) == 0)) {
        mapgen.addSecretDoor(map, p);
    }
}

fn makeGold(map: *Map, r: *std.Random, room: *Room) void {
    // FUTURE : if !amulet and if level < max_level
    if (r.intRangeAtMost(usize, 0, 1) == 0) { // 50%
        const pos = findFloor(r, room);
        mapgen.addItemToMap(map, pos, .gold);
    }
}

fn makeTraps(map: *Map, r: *std.Random, level: usize) void {
    // This is from the original sources

    if (r.intRangeAtMost(usize, 0, 9) >= level) {
        return;
    }

    const count = r.intRangeAtMost(usize, 1, @divTrunc(level, 4) + 1);
    for (0..count) |_| {
        const pos = findAnyFloor(r, map);
        if (map.getFeature(pos) == .none) {
            // TODO: definitely suboptimal.  findAnyFloor should only return empty floor
            mapgen.addTrap(map, pos);
        }
    }
}

// TODO: into Map?  It assumes a room grid
fn isRoomAdjacent(i: usize, j: usize) bool {
    const i_row = @divTrunc(i, rooms_dim);
    const j_row = @divTrunc(j, rooms_dim);
    const i_col = @mod(i, rooms_dim);
    const j_col = @mod(j, rooms_dim);

    if (i_row == j_row) { // neighbors, same row
        return if ((i == j + 1) or (j == i + 1)) true else false;
    } else if (i_col == j_col) { // neighbors, same column
        return if ((i_row == j_row + 1) or (j_row == i_row + 1)) true else false;
    }
    return false;
}

fn findFloor(r: *std.Random, room: *Room) Pos {
    // FIXME: want a spot without anything else
    const row = r.intRangeAtMost(Pos.Dim, room.getMinX() + 1, room.getMaxX() - 1);
    const col = r.intRangeAtMost(Pos.Dim, room.getMinY() + 1, room.getMaxY() - 1);
    return Pos.config(row, col);
}

fn findAnyFloor(r: *std.Random, map: *Map) Pos {
    const i = r.intRangeAtMost(usize, 0, max_rooms - 1);
    const room = mapgen.getRoom(map, i);

    return findFloor(r, room);
}

// Connection graph between rooms

fn setConnected(graph: []bool, r1: usize, r2: usize) void {
    graph[r1 * max_rooms + r2] = true;
    graph[r2 * max_rooms + r1] = true;
}

fn notConnected(graph: []bool, r1: usize, r2: usize) bool {
    return !graph[r1 * max_rooms + r2];
}

// Dig a passage

fn connectRooms(map: *Map, rn1: usize, rn2: usize, r: *std.Random) void {
    const i = @min(rn1, rn2); // Western or Northern
    const j = @max(rn1, rn2); // Eastern or Southern
    var r1 = mapgen.getRoom(map, i);
    var r2 = mapgen.getRoom(map, j);
    var d1: Pos = undefined;
    var d2: Pos = undefined;

    // Pick valid connection points (along the opposite room sides, not on
    // the corners, and a location for the midpoint)

    if (j == i + 1) { // Eastward dig
        const start_x = r1.getMaxX();
        const r1_y = r.intRangeAtMost(Pos.Dim, r1.getMinY() + 1, r1.getMaxY() - 1);
        const end_x = r2.getMinX();
        const r2_y = r.intRangeAtMost(Pos.Dim, r2.getMinY() + 1, r2.getMaxY() - 1);
        const mid_x = r.intRangeAtMost(Pos.Dim, start_x + 1, end_x - 1);
        mapgen.addEastCorridor(
            map,
            Pos.config(start_x, r1_y),
            Pos.config(end_x, r2_y),
            mid_x,
        );
        d1 = Pos.config(start_x, r1_y);
        d2 = Pos.config(end_x, r2_y);
    } else { // Southward dig
        const r1_x = r.intRangeAtMost(Pos.Dim, r1.getMinX() + 1, r1.getMaxX() - 1);
        const start_y = r1.getMaxY();
        const r2_x = r.intRangeAtMost(Pos.Dim, r2.getMinX() + 1, r2.getMaxX() - 1);
        const end_y = r2.getMinY();
        const mid_y = r.intRangeAtMost(Pos.Dim, start_y + 1, end_y - 1);
        mapgen.addSouthCorridor(
            map,
            Pos.config(r1_x, start_y),
            Pos.config(r2_x, end_y),
            mid_y,
        );
        d1 = Pos.config(r1_x, start_y);
        d2 = Pos.config(r2_x, end_y);
    }
    if (!r1.flags.gone) {
        makeDoor(map, r, d1);
    }
    if (!r2.flags.gone) {
        makeDoor(map, r, d2);
    }
}

fn reserveGoneRooms(map: *Map, rand: *std.Random) void {
    // Set aside some rooms as being 'gone'

    var i: usize = rand.intRangeAtMost(usize, 0, 3);
    while (i > 0) {
        const r = rand.intRangeAtMost(usize, 0, max_rooms - 1);
        const room = mapgen.getRoom(map, r);
        if (room.flags.gone) { // TODO - interface
            continue;
        }
        room.setGone();
        i -= 1;
    }
}

// ========================================================
//
// Interface Routines
//

//
// Add a player to a good place on the map
//

pub fn addPlayer(map: *Map, player: *Player, rand: *std.Random) void {
    mapgen.addEntityToMap(map, player.getEntity(), findAnyFloor(rand, map));
    player.resetMap();
    player.setDepth(@intCast(map.level)); // TODO: blecch
    player.revealMap(map, player.getPos()); // initial position
}

//
// Create a level using the traditional Rogue algorithms
//

pub fn create(config: Config, allocator: std.mem.Allocator) !*Map {
    var rand = config.rand;
    var ingraph = [_]bool{false} ** max_rooms; // Rooms connected to graph
    var connections = [_]bool{false} ** (max_rooms * max_rooms);
    var map = try Map.init(
        allocator,
        map_xsize,
        map_ysize,
        rooms_dim,
        rooms_dim,
    );
    errdefer map.deinit(allocator);

    map.level = config.level;

    reserveGoneRooms(map, rand);

    for (0..max_rooms) |i| {
        const r = mapgen.getRoom(map, i);
        if (r.flags.gone) { // TODO: interface
            mapgen.addRoom(map, makeGoneRoom(@intCast(i), map, rand));
            continue;
        }

        var room = makeRoom(@intCast(i), map, rand);
        mapgen.addRoom(map, room);
        makeGold(map, rand, &room);

        // FUTURE: Place monster
    }

    // Connect passages.  Start with first room in slice

    var r1: usize = rand.intRangeAtMost(usize, 0, max_rooms - 1);
    ingraph[r1] = true;
    var roomcount: usize = 1;

    // Find an adjacent room to connect with

    while (roomcount < max_rooms) {
        var j: usize = 0;
        var r2: usize = 1000;
        for (0..max_rooms) |i| {
            if (isRoomAdjacent(r1, i) and !ingraph[i]) {
                j += 1;
                if (rand.intRangeAtMost(usize, 0, j) == 0) {
                    r2 = @intCast(i);
                }
            }
        }
        if (r2 < 1000) {
            // Found adjacent room not already in graph
            ingraph[@intCast(r2)] = true;
            connectRooms(map, r1, r2, rand);
            setConnected(&connections, @intCast(r1), @intCast(r2));
            roomcount += 1;
        } else {
            // No adjacent rooms outside of graph: start over with a new room

            r1 = rand.intRangeAtMost(usize, 0, max_rooms - 1);
            while (ingraph[r1] == false) {
                r1 = rand.intRangeAtMost(usize, 0, max_rooms - 1);
            }
        }
    } // While roomcount < max_rooms

    // Add passages to the graph for loop variety

    roomcount = rand.intRangeAtMost(usize, 0, 4);
    while (roomcount > 0) {
        r1 = rand.intRangeAtMost(usize, 0, max_rooms - 1);

        // Find an adjacent room not already connected

        var j: usize = 0;
        var r2: usize = 1000;
        for (0..max_rooms) |i| {
            if (isRoomAdjacent(r1, i) and notConnected(&connections, r1, i)) {
                j += 1;
                if (rand.intRangeAtMost(usize, 0, j) == 0) {
                    r2 = @intCast(i);
                }
            }
        }
        if (r2 < 1000) {
            connectRooms(map, r1, r2, rand);
            setConnected(&connections, @intCast(r1), @intCast(r2));
        }

        roomcount -= 1;
    }

    // Place the traps

    makeTraps(map, rand, config.level);

    // Place the stairs.  In the original they can't go in a gone room, but why not?
    {
        const pos = findAnyFloor(rand, map);

        if (config.going_down) {
            map.setFloorTile(pos, .stairs_down);
        } else {
            map.setFloorTile(pos, .stairs_up);
        }
    }

    return map;
}

//
// Unit tests
//

const expect = std.testing.expect;
const tallocator = std.testing.allocator;

// Adjacency tests
//
// Apparently can't embed these in the test block

fn testsTrue(i: usize, j: usize) !void {
    try expect(isRoomAdjacent(i, j) == true);
    try expect(isRoomAdjacent(j, i) == true);
}

fn testsFalse(i: usize, j: usize) !void {
    try expect(isRoomAdjacent(i, j) == false);
    try expect(isRoomAdjacent(j, i) == false);
}

test "room adjacency" {
    try testsTrue(0, 3);
    try testsTrue(0, 1);
    try testsTrue(4, 5);
    try testsTrue(4, 3);
    try testsFalse(0, 2);
    try testsFalse(0, 4);
    try testsFalse(0, 5);
    try testsFalse(0, 7);
    try testsFalse(0, 8);
    try testsFalse(2, 3);
}

test "create Rogue level" {
    var prng = std.Random.DefaultPrng.init(0);
    var r = prng.random();

    const config = mapgen.Config{
        .rand = &r,
        .xSize = 80,
        .ySize = 24,
        .level = 2,
        .mapgen = .ROGUE,
    };

    var map = try create(config, tallocator);
    defer map.deinit(tallocator);

    try expect(map.level == 2);

    // DO-IT-NOW : prove that a stair was placed
}

test "fuzz test room generation" {
    const seed: u64 = @intCast(std.time.microTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    var r = prng.random();
    var map = try Map.init(tallocator, 80, 24, 3, 3);
    defer map.deinit(tallocator);

    for (0..rooms_dim) |y| {
        for (0..rooms_dim) |x| {
            const i: i16 = @intCast(y * rooms_dim + x);
            const room = makeRoom(i, map, &r);
            mapgen.addRoom(map, room);
        }
    }
}

test "fuzz test gone room generation" {
    const seed: u64 = @intCast(std.time.microTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    var r = prng.random();
    var map = try Map.init(tallocator, 80, 24, 3, 3);
    defer map.deinit(tallocator);

    for (0..rooms_dim) |y| {
        for (0..rooms_dim) |x| {
            const i: i16 = @intCast(y * rooms_dim + x);
            const room = makeGoneRoom(i, map, &r);
            mapgen.addRoom(map, room);

            // TODO test boundaries
        }
    }
}

// EOF
