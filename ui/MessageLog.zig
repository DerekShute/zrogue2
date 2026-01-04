//!
//! Message log as an abstraction
//!
//! Right now a one-line banner of event, with no significant storage and
//! no way to peruse

const std = @import("std");

//
// Constants
//

// TODO Fiat.  Matches map max and display min
const MESSAGE_MAXSIZE = 80; // TODO

const Self = @This();

//
// Members
//
// FUTURE: queue depth > 1
//

memory: [MESSAGE_MAXSIZE]u8 = undefined,
buffer: []u8 = &.{},

//
// Constructor/Destructor
//

pub fn init() Self {
    return .{};
}

//
// Methods
//

pub fn add(self: *Self, msg: []const u8) void {
    self.buffer = &self.memory; // Reset slice to max length and content
    @memcpy(self.buffer[0..msg.len], msg);
    self.buffer = self.buffer[0..msg.len]; // Fix up the slice for length
}

pub fn get(self: *Self) []u8 {
    return self.buffer;
}

pub fn clear(self: *Self) void {
    self.buffer = &.{}; // Reset to zero
}

//
// Unit Tests
//
const expect = std.testing.expect;

test "allocate and add messages" {
    var log = init();

    // Empty to begin
    var empty = log.get();
    try expect(empty.len == 0);

    log.add("A LOG MESSAGE");
    try expect(std.mem.eql(u8, log.get(), "A LOG MESSAGE"));

    // Repeat succeeds
    try expect(std.mem.eql(u8, log.get(), "A LOG MESSAGE"));

    // Change it
    log.add("SECOND MESSAGE");
    try expect(std.mem.eql(u8, log.get(), "SECOND MESSAGE"));

    // Clearing it empties it
    log.clear();
    empty = log.get();
    try expect(empty.len == 0);

    // Change it
    log.add("SECOND MESSAGE");
    try expect(std.mem.eql(u8, log.get(), "SECOND MESSAGE"));

    // (It does not test equal against superstrings or substrings)
    try expect(!std.mem.eql(u8, log.get(), "SECOND MESSAGE2"));
    try expect(!std.mem.eql(u8, log.get(), "SECOND MESSA"));
}

// EOF
