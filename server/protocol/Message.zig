//!
//! Message (from server)
//!   For now, only boring game-action related
//!
//!   message : max 80 characters
//!

const std = @import("std");
const msgpack = @import("msgpack");
const utils = @import("utils.zig");

const Reader = std.io.Reader;
const Writer = std.io.Writer;
const Allocator = std.mem.Allocator;

const Self = @This();

pub const max_message_len = 80;

//
// Members: do not supply defaults!
//

message: []u8,

//
// Lifecycle
//

pub fn copy(allocator: Allocator, basis: Self) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.message = try allocator.dupe(u8, basis.message);
    return s;
}

pub fn init(allocator: Allocator, message: []const u8) !*Self {
    if (message.len > max_message_len) {
        @panic("Message.init: message too long"); // Prevent this, please
    }
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.message = try allocator.dupe(u8, message);
    return s;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
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

pub fn read(reader: *Reader, allocator: Allocator) !*Self {
    return utils.genericRead(Self, reader, allocator);
}

//
// Unit testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;

const test_msg: *const [max_message_len:0]u8 = "*" ** max_message_len;

// boring use case

test "write and read" {
    // Beyond the allocation scheme: if this fails, testing must be reworked
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 2 });
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var sendmsg = try init(t_allocator, test_msg);
    defer sendmsg.deinit(t_allocator);

    try sendmsg.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    var msg = try read(&breader, f.allocator());
    defer msg.deinit(f.allocator());

    try expect(std.mem.eql(u8, msg.message, test_msg));
}

// write

test "write, memory failure 1" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

test "write, memory failure 2" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 1 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

// read

test "read, memory failure" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 1 });
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var sendreq = try init(t_allocator, "frammitz");
    defer sendreq.deinit(t_allocator);

    try sendreq.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    try expectError(error.OutOfMemory, read(&breader, f.allocator()));
}

// "message too long" protected by a panic in init(), so handcraft

test "receive fails validation (message length)" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    const smess = "*" ** 81;

    const message = try t_allocator.dupe(u8, smess);
    defer std.testing.allocator.free(message);

    const sendreq: Self = .{
        .message = message,
    };
    try msgpack.encode(sendreq, &bwriter);
    try bwriter.flush();

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.Invalid, read(&breader, t_allocator));
}

// EOF
