//!
//! Depart (either side) : player is leaving or is booted
//!
//!   message : max 80 characters
//!

const std = @import("std");
const msgpack = @import("msgpack");

const Writer = std.io.Writer;
const Reader = std.io.Reader;

const Self = @This();

pub const max_message_len = 80;

//
// Members
//

message: []u8 = undefined,

//
// Lifecycle
//

pub fn init(allocator: std.mem.Allocator, message: []const u8) !*Self {
    if (message.len > max_message_len) {
        @panic("Depart.init: message too long"); // Prevent this, please
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

//
// Methods
//

pub fn write(self: Self, writer: *Writer) !void {
    var buffer: [100]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    try msgpack.encode(self, &bwriter);
    try writer.writeAll(bwriter.buffered());
    try writer.flush();
}

pub fn read(reader: *Reader, allocator: std.mem.Allocator) !*Self {
    // Uses a constrained allocator here to prevent malicious actors
    var buffer: [250]u8 = undefined; // Calculated size
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const msg = try msgpack.decode(Self, fba.allocator(), reader);
    // error.OutOfMemory -> message could be too long

    if (msg.value.message.len > max_message_len) { // Borderline but enforce
        return error.OutOfMemory;
    }
    return try init(allocator, msg.value.message);
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
