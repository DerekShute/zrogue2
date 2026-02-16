//!
//! Message (from server)
//!   For now, only boring game-action related
//!
//!   message : max 80 characters
//!

const std = @import("std");
const msgpack = @import("msgpack");
const utils = @import("utils.zig");

const Self = @This();

pub const max_message_len = 80;

//
// Members
//

message: []u8 = undefined,

//
// Lifecycle
//

pub fn copy(allocator: std.mem.Allocator, basis: Self) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.message = try allocator.dupe(u8, basis.message);
    return s;
}

pub fn init(allocator: std.mem.Allocator, message: []const u8) !*Self {
    if (message.len > max_message_len) {
        @panic("Message.init: message too long"); // Prevent this, please
    }
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.message = try allocator.dupe(u8, message);
    return s;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.message);
    allocator.destroy(self);
}

pub fn valid(self: *Self) bool {
    if (self.message.len > max_message_len) { // Borderline but enforce
        return false;
    }
    return true;
}

//
// Methods
//

pub const write = utils.genericWrite;

pub fn read(reader: *std.io.Reader, allocator: std.mem.Allocator) !*Self {
    return utils.genericRead(Self, reader, allocator);
}

//
// Unit testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "write and read" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const message: *const [max_message_len:0]u8 = "*" ** max_message_len;

    var sendmsg = try init(std.testing.allocator, message);
    defer sendmsg.deinit(std.testing.allocator);

    try sendmsg.write(&bwriter);
    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    var msg = try read(&breader, std.testing.allocator);
    defer msg.deinit(std.testing.allocator);

    try expect(std.mem.eql(u8, msg.message, message));
}

// TODO: allocation failures, structure failures, etc.

// EOF
