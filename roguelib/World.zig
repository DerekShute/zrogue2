//!
//! Game World : primitive elements of the game in one place
//!

const std = @import("std");

const Entity = @import("Entity.zig");
const EventQueue = @import("EventQueue.zig");
const Map = @import("Map.zig");

const Self = @This();

//
// Types
//

pub const MapKey = usize;
const HashedMaps = std.AutoHashMapUnmanaged(MapKey, *Map);

//
// Vector Table
//

pub const VTable = struct {
    // enter - player enters Game
    enter: *const fn (self: *Self, entity: *Entity) void,
};

//
// Members
//

// Primitives

allocator: std.mem.Allocator = undefined,
io: std.Io = undefined,
random: std.Random = undefined,
vtable: ?*const VTable = null,

single_player: bool = false, // true - end when player departs

// Game elements and environment

maps: HashedMaps = undefined,
queue: EventQueue = undefined, // TODO: mapgen?

//
// Lifecycle
//

pub fn init(vtable: ?*const VTable) Self {
    return .{
        .queue = .init,
        .maps = .empty,
        .vtable = vtable,
    };
}

pub fn configIo(self: *Self, io: std.Io) void {
    self.io = io;
}

pub fn configAllocator(self: *Self, allocator: std.mem.Allocator) void {
    self.allocator = allocator;
}

pub fn configRandom(self: *Self, random: std.Random) void {
    self.random = random;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    defer self.maps.deinit(allocator);

    var iter = self.maps.valueIterator();
    while (iter.next()) |value_ptr| {
        value_ptr.*.deinit(allocator);
    }
    self.queue.deinit(allocator);
}

//
// Methods
//

// TODO: entropy

// TODO: mapgen, map lookup

// Event queue

pub fn enqueueAction(self: *Self, entity: *Entity) void {
    self.queue.enqueue(
        self.io,
        self.allocator,
        .{ .action = .{ .entity = entity } },
    ) catch {
        @panic("enqueueAction: error");
    };
}

// enqueueEntry: Add player (Entity) to the Game.
pub fn enqueueEntry(self: *Self, entity: *Entity) void {
    self.queue.enqueue(
        self.io,
        self.allocator,
        .{ .entry = .{ .entity = entity } },
    ) catch {
        @panic("enqueueEntry: error");
    };
}

pub fn nextEvent(self: *Self) ?EventQueue.Event {
    return self.queue.next(self.io, self.allocator);
}

// FUTURE: dequeue by Entity pointer?

// Map management

pub fn addMap(self: *Self, key: MapKey, map: *Map) !void {
    try self.maps.put(self.allocator, key, map);
}

pub fn getMap(self: *Self, key: MapKey) *Map {
    if (self.maps.get(key)) |map| {
        return map;
    }
    @panic("getMap: no such key");
}

pub fn removeMap(self: *Self, key: MapKey) void {
    if (self.maps.fetchRemove(key)) |kv| {
        kv.value.deinit(self.allocator);
    }
}

//
// World Run
//

fn entryEvent(self: *Self, entity: *Entity) void {
    if (self.vtable) |vt| {
        vt.enter(self, entity);
        self.enqueueAction(entity);
    } else unreachable;
}

fn actionEvent(self: *Self, entity: *Entity) bool {
    const result = entity.doAction(self) catch {
        // TODO: message etc
        return false;
    };
    if (self.single_player) {
        if (result == .depart) {
            return false;
        }

        self.enqueueAction(entity); // May need callback here
    }

    return true;
}

pub fn step(self: *Self) bool { // true: keep going
    if (self.nextEvent()) |event| switch (event) {
        .entry => |entry_event| {
            self.entryEvent(entry_event.entity);
            return true;
        },
        .action => |action_event| {
            return self.actionEvent(action_event.entity);
        },
    };
    return false; // For lack of a better idea
}

pub fn run(self: *Self) void {
    // TODO: clock tick here?
    while (self.step()) {}
}

//
// Unit tests
//

const MockEntity = @import("testing/MockEntity.zig");
const expect = std.testing.expect;

test "basic map use" {
    var s = Self.init(null);
    s.configIo(std.testing.io);
    s.configAllocator(std.testing.allocator);
    defer s.deinit(std.testing.allocator);

    const first = try Map.init(std.testing.allocator, 20, 20, 1, 1);
    try s.addMap(0, first);

    for (1..6) |i| {
        try s.addMap(i, try Map.init(std.testing.allocator, 20, 20, 1, 1));
    }

    try expect(s.getMap(0) == first);

    for (1..6) |i| {
        s.removeMap(i);
    }
}

test "basic action use" {
    var m = MockEntity.init();
    m.setNext(.depart);

    var s = Self.init(null);
    s.single_player = true;
    s.configIo(std.testing.io);
    s.configAllocator(std.testing.allocator);
    defer s.deinit(std.testing.allocator);
    try s.addMap(0, try Map.init(std.testing.allocator, 20, 20, 1, 1));

    s.enqueueAction(m.getEntity());
    try expect(s.step() == false);
}

test "action error" {
    var m = MockEntity.init();
    m.setError();

    var s = Self.init(null);
    s.single_player = true;
    s.configIo(std.testing.io);
    s.configAllocator(std.testing.allocator);
    defer s.deinit(std.testing.allocator);
    try s.addMap(0, try Map.init(std.testing.allocator, 20, 20, 1, 1));

    s.enqueueAction(m.getEntity());
    try expect(s.step() == false);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
