//!
//! Event Queue: events for the engine to process (entity actions, timer, etc)
//!

const std = @import("std");
const Entity = @import("Entity.zig");

const Self = @This();

queue: Entity.Queue = undefined, // FUTURE: more abstract type
mutex: std.Io.Mutex = undefined,
condition: std.Io.Condition = undefined,

//
// Types
//

pub const Event = struct {
    // FUTURE: union, more flexible
    entity: *Entity,
};

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

    self.queue.enqueue(event.entity);
    self.condition.signal(io);
}

// FUTURE: dequeue, which will have to be a search

pub fn next(self: *Self, io: std.Io) ?Event {
    self.mutex.lock(io) catch unreachable; // TODO: Async
    defer self.mutex.unlock(io);

    var entity: ?*Entity = self.queue.next();
    while (entity == null) {
        self.condition.wait(io, &self.mutex) catch unreachable;
        entity = self.queue.next();
    }
    return .{ .entity = entity.? };
}

//
// Unit tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const tallocator = std.testing.allocator;

test "basic use" {
    var vt: Entity.VTable = .{};
    var e = Entity.init(.{ .tile = @enumFromInt(4), .vtable = &vt });

    var s: Self = .init;

    // Can't test for empty here because it will block

    s.enqueue(std.testing.io, Event{ .entity = &e });
    const n = s.next(std.testing.io);

    try expect(n.?.entity == &e);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
