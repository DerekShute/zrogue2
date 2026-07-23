//!
//! Event Queue: events for the engine to process (entity actions, timer, etc)
//!

const std = @import("std");
const Entity = @import("Entity.zig");

const Self = @This();

//
// Types
//

pub const Tag = enum {
    action,
    // TODO: entry,
    // FUTURE: departure
};

pub const Event = union(Tag) {
    // entry: struct {
    //    entity: *Entity,
    //    map_id: usize,
    // },
    action: struct {
        entity: *Entity,
    },
};

//
// Members
//

queue: Entity.Queue = undefined, // FUTURE: more abstract type
mutex: std.Io.Mutex = undefined,
condition: std.Io.Condition = undefined,

//
// Lifecycle
//

pub const init: Self = .{
    .queue = .config(),
    .mutex = .init,
    .condition = .init,
};

pub fn enqueue(self: *Self, io: std.Io, event: Event) void {
    self.mutex.lock(io) catch unreachable; // TODO: Async
    defer self.mutex.unlock(io);

    self.queue.enqueue(event.action.entity); // TODO
    self.condition.signal(io);
}

// FUTURE: dequeue, which will have to be a search

pub fn next(self: *Self, io: std.Io) Event {
    self.mutex.lock(io) catch unreachable; // TODO: Async
    defer self.mutex.unlock(io);

    var entity: ?*Entity = self.queue.next();
    while (entity == null) {
        self.condition.wait(io, &self.mutex) catch unreachable;
        entity = self.queue.next();
    }
    return .{ .action = .{ .entity = entity.? } };
}

//
// Unit tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const tallocator = std.testing.allocator;
const MockEntity = @import("testing/MockEntity.zig");

test "action use" {
    var e = MockEntity.init();
    var s: Self = .init;

    // Can't test for empty here because it will block

    s.enqueue(std.testing.io, Event{ .action = .{ .entity = e.getEntity() } });
    const n = s.next(std.testing.io);

    try expect(n.action.entity == e.getEntity());
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
