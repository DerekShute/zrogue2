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
    addEntity: *const fn (self: *Self, entity: *Entity, map: *Map) void,
};

//
// Members
//

// Primitives

allocator: std.mem.Allocator = undefined,
io: std.Io = undefined,
random: std.Random = undefined,
vtable: ?*const VTable = null,

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
}

//
// Methods
//

pub fn addEntity(self: *Self, entity: *Entity, map_id: usize) void {
    if (self.vtable) |vt| {
        const map = self.getMap(map_id);
        entity.setMapId(map_id);
        self.enqueueAction(entity);
        vt.addEntity(self, entity, map);
    }
}

// TODO: entropy

// TODO: mapgen, map lookup

// Event queue

pub fn enqueueAction(self: *Self, entity: *Entity) void {
    self.queue.enqueue(self.io, .{ .action = .{ .entity = entity } });
}

pub fn nextEvent(self: *Self) ?EventQueue.Event {
    return self.queue.next(self.io);
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
    unreachable; // Assumption for the moment
}

pub fn removeMap(self: *Self, key: MapKey) void {
    if (self.maps.fetchRemove(key)) |kv| {
        kv.value.deinit(self.allocator);
    }
}

// Play

pub const State = enum { // Simple state machine: intro -> run -> end
    run,
    descend, // hacky - let wrapper determine what this entails
    ascend,
    end,
};

pub fn run(self: *Self) State {
    const map = self.getMap(0); // NOCOMMIT stupid stupid
    while (self.nextEvent()) |event| {
        const entity = event.action.entity; // FUTURE: other event types
        const result = entity.doAction(map) catch {
            return .end;
        };
        switch (result) {
            .continue_game => {
                // FUTURE: do not requeue - figure out how to do so from
                // an incoming command (via Client?).  Else server spins
                self.enqueueAction(entity);
                continue;
            },
            .end_game => {
                map.removeEntity(entity.getPos()); // NOCOMMIT appalling
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
    m.setNext(.ascend); // TODO this is a sleaze

    var s = Self.init(null);
    s.configIo(std.testing.io);
    s.configAllocator(std.testing.allocator);
    defer s.deinit(std.testing.allocator);
    try s.addMap(0, try Map.init(std.testing.allocator, 20, 20, 1, 1));

    s.enqueueAction(m.getEntity());
    try expect(s.run() == .ascend);
}

test "action error" {
    var m = MockEntity.init();
    m.setError();

    var s = Self.init(null);
    s.configIo(std.testing.io);
    s.configAllocator(std.testing.allocator);
    defer s.deinit(std.testing.allocator);
    try s.addMap(0, try Map.init(std.testing.allocator, 20, 20, 1, 1));

    s.enqueueAction(m.getEntity());
    try expect(s.run() == .end);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
