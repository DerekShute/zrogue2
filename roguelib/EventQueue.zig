//!
//! Event Queue: events for the engine to process (entity actions, timer, etc)
//!

const std = @import("std");
const Entity = @import("Entity.zig");
const queue = @import("queue.zig");

const Allocator = std.mem.Allocator;
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

const Node = struct {
    payload: Event,
    node: queue.Node = .{},
};
const Queue = queue.Queue(Node, "node");

//
// Members
//

q: Queue = undefined,
mutex: std.Io.Mutex = undefined,
condition: std.Io.Condition = undefined,

//
// Lifecycle
//

pub const init: Self = .{
    .q = .config(),
    .mutex = .init,
    .condition = .init,
};

pub fn deinit(self: *Self, allocator: Allocator) void {
    var current: ?*Node = self.q.next();
    while (current) |c| {
        const n = self.q.next();
        allocator.destroy(c);
        current = n;
    }
}

pub fn enqueue(self: *Self, io: std.Io, allocator: Allocator, event: Event) !void {
    var node = try allocator.create(Node);
    errdefer allocator.destroy(node);
    node.payload = event;

    try self.mutex.lock(io);
    defer self.mutex.unlock(io);

    self.q.enqueue(node);
    self.condition.signal(io);
}

// FUTURE: dequeue, which will have to be a search

pub fn next(self: *Self, io: std.Io, allocator: Allocator) Event {
    self.mutex.lock(io) catch unreachable; // TODO: Async
    defer self.mutex.unlock(io);

    var node = self.q.next();
    while (node == null) {
        self.condition.wait(io, &self.mutex) catch unreachable;
        node = self.q.next();
    }

    const payload = node.?.payload;
    allocator.destroy(node.?);
    return payload;
}

//
// Unit tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const tallocator = std.testing.allocator;
const MockEntity = @import("testing/MockEntity.zig");

test "basic use" {
    var e = MockEntity.init();
    var s: Self = .init;
    defer s.deinit(std.testing.allocator);

    try s.enqueue(
        std.testing.io,
        std.testing.allocator,
        Event{ .action = .{ .entity = e.getEntity() } },
    );
    try s.enqueue(
        std.testing.io,
        std.testing.allocator,
        Event{ .action = .{ .entity = e.getEntity() } },
    );
    try s.enqueue(
        std.testing.io,
        std.testing.allocator,
        Event{ .action = .{ .entity = e.getEntity() } },
    );

    _ = s.next(std.testing.io, std.testing.allocator);
    _ = s.next(std.testing.io, std.testing.allocator);
    // The last is cleaned up
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
