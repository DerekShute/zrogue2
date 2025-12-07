//!
//! Maps and everything that implements and abstracts
//!

const std = @import("std");

const Entity = @import("Entity.zig");
const Grid = @import("grid.zig").Grid;
const MapTile = @import("maptile.zig").MapTile;
const Pos = @import("Pos.zig");
const Place = @import("map/Place.zig");
const Region = @import("Region.zig");
const Room = @import("map/Room.zig");
const Tileset = @import("maptile.zig").Tileset;

const PlaceGrid = Grid(Place);

const Self = @This();

//
// Errors
//

pub const Error = error{
    OutOfBounds,
    IndexOverflow,
};

//
// Members
//

places: PlaceGrid = undefined,
rooms: []Room = undefined,
height: Pos.Dim = 0,
width: Pos.Dim = 0,
roomsx: Pos.Dim = 0,
roomsy: Pos.Dim = 0,
level: usize = 1,

//
// Constructor / destructor
//

pub fn init(allocator: std.mem.Allocator, width: Pos.Dim, height: Pos.Dim, roomsx: Pos.Dim, roomsy: Pos.Dim) !*Self {
    if ((height <= 0) or (width <= 0) or (roomsx <= 0) or (roomsy <= 0)) {
        @panic("Map.init: Bad arg passed");
    }

    // Arguable that this should just return a structure by value
    const m: *Self = try allocator.create(Self);
    errdefer allocator.destroy(m);

    const places = try PlaceGrid.config(allocator, @intCast(width), @intCast(height));
    errdefer places.deinit(allocator);

    var p = places.iterator();
    while (p.next()) |place| {
        place.config();
    }

    const rooms = try allocator.alloc(Room, @intCast(roomsx * roomsy));
    errdefer allocator.free(rooms);
    for (rooms) |*room| {
        room.* = Room.config(Pos.config(0, 0), Pos.config(0, 0));
    }

    m.height = height;
    m.width = width;
    m.places = places;
    m.rooms = rooms;
    m.roomsx = roomsx;
    m.roomsy = roomsy;

    return m;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.places.deinit(allocator);
    allocator.free(self.rooms);
    allocator.destroy(self);
}

//
// Utility
//

fn toPlace(self: *Self, p: Pos) *Place {
    const x: usize = @intCast(p.getX());
    const y: usize = @intCast(p.getY());
    const place = self.places.find(x, y) catch {
        @panic("Bad pos sent to Map.toPlace"); // Think: error?
    };
    return place;
}

//
// Methods
//

pub fn addEntity(self: *Self, e: *Entity, p: Pos) void {
    if (!p.eql(e.getPos())) {
        @panic("Map.addEntity: Entity not set to position\n");
    }
    self.toPlace(p).setEntity(e);
}

pub fn getHeight(self: *Self) Pos.Dim {
    return self.height;
}

pub fn getWidth(self: *Self) Pos.Dim {
    return self.width;
}

pub fn getDepth(self: *Self) usize {
    return self.level;
}

pub fn getTileset(self: *Self, p: Pos) Tileset {
    return self.toPlace(p).getTileset();
}

pub fn getFloorTile(self: *Self, p: Pos) MapTile { // TODO deprecated
    return self.toPlace(p).getTile();
}

pub fn setTile(self: *Self, p: Pos, tile: MapTile) void { // TODO deprecated
    self.toPlace(p).setTile(tile);
}

pub fn passable(self: *Self, p: Pos) bool {
    return self.toPlace(p).passable();
}

//
// Map Iterator
//
// Every location on the map
//

pub const Iterator = struct {
    m: *Self = undefined,
    x: Pos.Dim = 0,
    y: Pos.Dim = 0,

    // TODO: This could use a Region and its iterator but there's
    // pointer and storage confusion...maybe a Region as part of the map?

    pub fn next(self: *Iterator) ?Pos {
        const oldx = self.x;
        const oldy = self.y;
        if (self.y > self.m.getHeight() - 1) {
            return null;
        } else if (self.x >= self.m.getWidth() - 1) { // next row
            self.y = self.y + 1;
            self.x = 0;
        } else {
            self.x = self.x + 1; // next column
        }
        return Pos.config(oldx, oldy);
    }
};

pub fn iterator(self: *Self) Iterator {
    return .{ .m = self };
}

//
// rooms
//

fn getRoomNum(self: *Self, p: Pos) ?usize {
    if ((p.getX() < 0) or (p.getY() < 0)) {
        return null;
    } else if ((p.getX() >= self.width) or (p.getY() >= self.height)) {
        return null;
    }

    const xsize = @divTrunc(self.width, self.roomsx); // spaces per column
    const ysize = @divTrunc(self.height, self.roomsy); // spaces per row
    const column = @divTrunc(p.getX(), xsize);
    const row = @divTrunc(p.getY(), ysize);
    const loc: usize = @intCast(row * self.roomsy + column);

    if (loc >= self.rooms.len) {
        return null;
    }

    return loc;
}

// TODO Future: getRoomNum is a mapgen thing
fn getRoom(self: *Self, p: Pos) ?*Room {
    if (self.getRoomNum(p)) |loc| {
        return &self.rooms[loc];
    }
    return null;
}

fn getInRoom(self: *Self, p: Pos) ?*Room {
    // If in the room, return it, else null
    if (self.getRoom(p)) |room| {
        if (room.isInside(p)) {
            return room;
        }
    } // else ugh

    return null;
}

pub fn inRoom(self: *Self, p: Pos) bool {
    if (self.getRoom(p)) |room| {
        return room.isInside(p);
    }
    return false; // TODO: ugh
}

pub fn getRoomRegion(self: *Self, p: Pos) !Region {
    if (self.getRoom(p)) |room| {
        return room.getRegion();
    }
    return error.OutOfBounds;
}

pub fn addRoom(self: *Self, room: Room) void {
    var r = room; // force to var reference

    // Minimum is 3x3 : two walls plus one tile
    if ((r.getMaxX() - r.getMinX() < 2) or (r.getMaxY() - r.getMinY() < 2)) {
        @panic("addRoom: Invalid room size");
    }

    // Rooms have a validated Region inside, so no need to test...
    // ...unless paranoid

    // getRoom() validates coordinates

    // Make sure that the region fits in one 'grid' location
    var sr = self.getRoom(Pos.config(r.getMinX(), r.getMinY()));
    const sr2 = self.getRoom(Pos.config(r.getMaxX(), r.getMaxY()));
    if (sr == null) {
        @panic("addRoom: room minimum off of map");
    } else if (sr2 == null) {
        @panic("addRoom: room maximum off of map");
    } else if (sr != sr2) {
        @panic("addRoom: room spans a room box");
    }

    // sr proven non-null above

    if (sr.?.getMaxX() != 0) {
        @panic("addRoom: Room already defined");
    }

    sr.?.* = r;
}

pub fn isLit(self: *Self, p: Pos) bool {
    if (self.getRoom(p)) |room| {
        if (room.isInside(p)) {
            return room.isLit();
        }
    }
    return false; // TODO: ugh
}

//
// Unit Tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;

// Rooms

test "add a room and ask about it" {
    var map = try init(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit(std.testing.allocator);

    const r1 = Room.config(Pos.config(5, 5), Pos.config(10, 10));
    map.addRoom(r1);
    try expect(map.inRoom(Pos.config(7, 7)) == true);
    try expect(map.inRoom(Pos.config(19, 19)) == false);
    try expect(map.inRoom(Pos.config(-1, -1)) == false);
}

// Map

test "map smoke test" {
    var map = try init(std.testing.allocator, 100, 50, 1, 1);
    defer map.deinit(std.testing.allocator);

    map.addRoom(Room.config(Pos.config(10, 10), Pos.config(20, 20)));
    map.setTile(Pos.config(15, 15), .stairs_down);
    try expect(map.getFloorTile(Pos.config(15, 15)) == .stairs_down);
    map.setTile(Pos.config(16, 16), .stairs_up);
    try expect(map.getFloorTile(Pos.config(16, 16)) == .stairs_up);

    try expect(map.getHeight() == 50);
    try expect(map.getWidth() == 100);
}

test "fails to allocate map" { // first allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const allocator = failing.allocator();

    try expectError(error.OutOfMemory, init(allocator, 10, 10, 1, 1));
}

test "fails to allocate places of map" { // second allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const allocator = failing.allocator();

    try expectError(error.OutOfMemory, init(allocator, 10, 10, 1, 1));
}

test "fails to allocate rooms of map" { // third allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 2 });
    const allocator = failing.allocator();

    try expectError(error.OutOfMemory, init(allocator, 10, 10, 10, 10));
}

test "Map Iterator" {
    const ARRAYDIM = 14;
    var a = [_]u8{0} ** (ARRAYDIM * ARRAYDIM);
    var map = try init(std.testing.allocator, ARRAYDIM, ARRAYDIM, 1, 1);
    defer map.deinit(std.testing.allocator);
    var i = map.iterator();

    // Just like the Region test but this covers the map

    while (i.next()) |pos| {
        const f: usize = @intCast(pos.getX() + pos.getY() * ARRAYDIM);
        try expect(pos.getX() >= 0);
        try expect(pos.getX() < ARRAYDIM);
        try expect(pos.getY() >= 0);
        try expect(pos.getY() < ARRAYDIM);
        a[f] = 1;
        _ = map.getFloorTile(pos); // Doesn't panic?  Good for you!
    }

    // Everything should have been touched

    for (0..ARRAYDIM) |y| {
        for (0..ARRAYDIM) |x| {
            try expect(a[x + y * ARRAYDIM] == 1);
        }
    }
}

// Invalid size maps guarded by panic

// Invalid position on map guarded by panic

//
// Attempting to add an invalid room is prevented by a panic so we can get to
// the bottom of why it was even attempted.  This includes:
//
// * rooms that would go off the map
// * rooms that cross 'room boundaries'
// * rooms smaller than a useful minimum (3x3)
// * rooms that have already been described
//

test "inquire about room at invalid location" {
    var map = try init(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit(std.testing.allocator);

    try expectError(error.OutOfBounds, map.getRoomRegion(Pos.config(21, 21)));
    try expectError(error.OutOfBounds, map.getRoomRegion(Pos.config(-1, -1)));

    try expect(map.getRoomNum(Pos.config(19, 0)) == 0);
    try expect(map.getRoomNum(Pos.config(20, 0)) == null);
    try expect(map.getRoomNum(Pos.config(0, 20)) == null);
    try expect(map.getRoomNum(Pos.config(0, 19)) == 0);

    // The rest are inquiries that we default to 'false' for insane callers
    // commence groaning now

    try expect(map.inRoom(Pos.config(20, 0)) == false);
    try expect(map.inRoom(Pos.config(100, 100)) == false);
    try expect(map.inRoom(Pos.config(-1, -1)) == false);
    try expect(map.inRoom(Pos.config(-1, -1)) == false);
    try expect(map.isLit(Pos.config(-1, -1)) == false);
    try expect(map.isLit(Pos.config(100, 100)) == false);
}

test "map multiple rooms" {
    var map = try init(std.testing.allocator, 100, 100, 2, 2);
    defer map.deinit(std.testing.allocator);

    const r1 = Room.config(Pos.config(0, 0), Pos.config(10, 10));
    map.addRoom(r1);
    const r2 = Room.config(Pos.config(60, 20), Pos.config(70, 30));
    map.addRoom(r2);
}

// EOF
