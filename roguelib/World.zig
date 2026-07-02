//!
//! Game World : primitive elements of the game in one place
//!

const std = @import("std");

const Entity = @import("Entity.zig");
const EventQueue = @import("EventQueue.zig");
const Map = @import("Map.zig");

const Self = @This();

//
// Members
//

// Primitives

allocator: std.mem.Allocator = undefined,
io: std.Io = undefined,
random: std.Random = undefined,

// Game elements and environment

map: *Map = undefined, // FUTURE: hashmap or something
// TODO: mapgen?
queue: EventQueue = undefined,

//
// Lifecycle
//

pub const init: Self = .{
    .queue = .init,
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

//
// Unit tests
//

test "basic use" {
    var s: Self = .init;
    s.configIo(std.testing.io);
    s.configAllocator(std.testing.allocator);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
