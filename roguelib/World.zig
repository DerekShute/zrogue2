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
// Members
//

// Primitives

allocator: std.mem.Allocator = undefined,
io: std.Io = undefined,
random: std.Random = undefined,

// Game elements and environment

map: *Map = undefined, // NOCOMMIT: leaving
maps: HashedMaps = undefined,
queue: EventQueue = undefined, // TODO: mapgen?

//
// Lifecycle
//

pub const init: Self = .{
    .queue = .init,
    .map = undefined, // NOCIMMIT: leaving
    .maps = .empty,
};

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
}

//
// Methods
//

// TODO: entropy

// TODO: mapgen, map lookup

// Event queue

pub fn enqueueEvent(self: *Self, event: EventQueue.Event) void {
    self.queue.enqueue(self.io, event);
}

pub fn nextEvent(self: *Self) ?EventQueue.Event {
    return self.queue.next(self.io);
}

// FUTURE: dequeue by Entity pointer?

// Map management

pub fn addMap(self: *Self, key: MapKey, map: *Map) !void {
    try self.maps.put(self.allocator, key, map);
}

pub fn getMap(self: *Self, key: MapKey) ?*Map {
    return self.maps.get(key);
}

// Play

pub const State = enum { // Simple state machine: intro -> run -> end
    run,
    descend, // hacky - let wrapper determine what this entails
    ascend,
    end,
};

pub fn run(self: *Self) State {
    while (self.nextEvent()) |event| {
        const entity = event.entity; // FUTURE: other event types
        const result = entity.doAction(self.map) catch {
            return .end;
        };
        switch (result) {
            .continue_game => {
                // FUTURE: do not requeue - figure out how to do so from
                // an incoming command (via Client?).  Else server spins
                self.enqueueEvent(.{ .entity = entity });
                continue;
            },
            .end_game => {
                self.map.removeEntity(entity.getPos());
                return .end;
            },
            // TODO: ascend/descend needs real map management and this breaks
            // the current 'rogue' model of new maps on the way back up

            .ascend => return .ascend,
            .descend => return .descend,
        }
    }

    // No entity left on queue
    return .run;
}

//
// Unit tests
//

const MockEntity = @import("testing/MockEntity.zig");
const expect = std.testing.expect;

test "basic map use" {
    var s: Self = .init;
    s.configIo(std.testing.io);
    s.configAllocator(std.testing.allocator);
    defer s.deinit(std.testing.allocator);

    const first = try Map.init(std.testing.allocator, 20, 20, 1, 1);
    try s.addMap(0, first);

    for (1..6) |i| {
        try s.addMap(i, try Map.init(std.testing.allocator, 20, 20, 1, 1));
    }

    try expect(s.getMap(0) == first);
}

test "basic action use" {
    var m = MockEntity.init();
    m.setNext(.ascend); // TODO this is a sleaze

    var s: Self = .init;
    s.configIo(std.testing.io);
    s.configAllocator(std.testing.allocator);
    defer s.deinit(std.testing.allocator);

    s.enqueueEvent(.{ .entity = m.getEntity() });
    try expect(s.run() == .ascend);
}

test "action error" {
    var m = MockEntity.init();
    m.setError();

    var s: Self = .init;
    s.configIo(std.testing.io);
    s.configAllocator(std.testing.allocator);
    defer s.deinit(std.testing.allocator);

    s.enqueueEvent(.{ .entity = m.getEntity() });
    try expect(s.run() == .end);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
