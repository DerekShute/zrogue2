//!
//! Server library stashed here for convenience.  Import on client side
//!
//! Transaction:
//!
//!    ENTRY msgpack ->
//! [
//!                  <- MAP_UPDATE msgpack
//!                  <- MESSAGE msgpack
//!                  <- STAT_UPDATE msgpack
//!
//!   ACTION msgpack ->
//! ]
//!
//!   DEPART msgpack ->
//!                 (or)
//!                  <- DEPART msgpack
//!
//!                  <- ERROR msgpack
//!

const std = @import("std");
const Writer = std.io.Writer;
const Reader = std.io.Reader;

//
// Master enumeration for messages
//

pub const MessageType = enum(u16) { // List controlled by protocol version
    depart,
    entry_request,
    message,

    const Self = @This();

    pub fn read(reader: *Reader) !Self {
        var buffer: [2]u8 = undefined;

        try reader.readSliceAll(&buffer);
        const val = std.mem.readInt(u16, &buffer, .big);

        if (val > @intFromEnum(Self.message)) {
            return Error.BadMessage;
        }
        return @enumFromInt(val);
    }

    pub fn write(mt: Self, writer: *Writer) !void {
        var buffer: [2]u8 = undefined;

        // TODO Could panic on > message

        std.mem.writeInt(u16, &buffer, @intFromEnum(mt), .big);
        try writer.writeAll(buffer[0..]);
        try writer.flush();
    }
};

//
// Message listing
//

pub const Depart = @import("protocol/Depart.zig");
pub const EntryRequest = @import("protocol/EntryRequest.zig");
pub const Message = @import("protocol/Message.zig");

//
// Constants
//

pub const max_player_name_length = EntryRequest.max_name_len;
pub const max_game_message_length = Message.max_message_len;

//
// Errors, to purify the raw error results
//

pub const Error = error{
    BadMessage,
    ConnectionDropped,
    ProtocolError,
    SendError,
    UnexpectedError,
};

//
// Service Routines
//

fn Wrap(comptime T: type) type {
    return struct {
        // OutOfMemory also includes failure of message validation
        pub fn read(allocator: std.mem.Allocator, reader: *Reader) !*T {
            const m = T.read(reader, allocator) catch |err| switch (err) {
                error.EndOfStream => return Error.ConnectionDropped,
                error.InvalidFormat => return Error.BadMessage, // not msgpack, etc.
                error.MissingStructFields => return Error.BadMessage,
                error.OutOfMemory => return Error.BadMessage, // Too long, etc.
                error.UnknownStructField => return Error.BadMessage,
                else => return Error.UnexpectedError,
            };
            return m;
        }

        pub fn write(self: *T, writer: *Writer) !void {
            self.write(writer) catch |err| switch (err) {
                error.WriteFailed => return Error.SendError,
                else => return Error.UnexpectedError,
            };
        }
    };
}

//
// Public Routines
//

// Entry Request

pub const readEntryRequest = Wrap(EntryRequest).read;

pub fn writeEntryRequest(
    writer: *Writer,
    name: []const u8,
) !void {
    const write = Wrap(EntryRequest).write;

    var alloc_b: [30]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = EntryRequest.init(fba.allocator(), name) catch unreachable;
    defer msg.deinit(fba.allocator());

    try MessageType.write(.entry_request, writer);
    try write(msg, writer);
}

// Depart

pub const readDepart = Wrap(Depart).read;

pub fn writeDepart(
    writer: *Writer,
    message: []const u8,
) !void {
    const write = Wrap(Depart).write;

    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    var msg = Depart.init(fba.allocator(), message) catch unreachable;
    defer msg.deinit(fba.allocator());

    try MessageType.write(.depart, writer);
    try write(msg, writer);
}

// Message

pub const readMessage = Wrap(Message).read;

pub fn writeMessage(
    writer: *Writer,
    message: []const u8,
) !void {
    const write = Wrap(Message).write;

    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    var msg = Message.init(fba.allocator(), message) catch unreachable;
    defer msg.deinit(fba.allocator());

    try MessageType.write(.message, writer);
    try write(msg, writer);
}

//
// Dispatch reader
//

pub fn readNext(reader: *Reader, allocator: std.mem.Allocator) !void {
    _ = try switch (try MessageType.read(reader)) {
        .depart => readDepart(allocator, reader),
        .entry_request => readEntryRequest(allocator, reader),
        .message => readMessage(allocator, reader),
    };
}

//
// Unit Testing
//
const expectError = std.testing.expectError;
const expect = std.testing.expect;

test "Entry sequence" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try writeEntryRequest(&bwriter, "frammitzor");

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    _ = try MessageType.read(&breader);

    const req = try readEntryRequest(std.testing.allocator, &breader);
    defer req.deinit(std.testing.allocator);

    try expect(std.mem.eql(u8, req.name, "frammitzor"));

    bwriter = std.io.Writer.fixed(&buffer); // Reset

    // TODO: other transactions

    try writeDepart(&bwriter, "client is disconnecting");

    breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    _ = try MessageType.read(&breader);

    const depart = try readDepart(std.testing.allocator, &breader);
    defer depart.deinit(std.testing.allocator);

    try expect(std.mem.eql(u8, depart.message, "client is disconnecting"));
}

test "MessageType mappings" {
    var buffer: [10]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    var mt: MessageType = .message; // Last one by design

    try mt.write(&bwriter);

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    try expect(mt == try MessageType.read(&breader));
}

test "MessageType bad mappings" {
    var buf: [2]u8 = undefined;

    std.mem.writeInt(u16, &buf, @intFromEnum(MessageType.message) + 1, .big);

    var breader = std.io.Reader.fixed(buf[0..]);

    try expectError(error.BadMessage, MessageType.read(&breader));
}

test "MessageType very bad mappings" {
    var buf: [2]u8 = undefined;

    std.mem.writeInt(u16, &buf, 0xFFFF, .big);

    var breader = std.io.Reader.fixed(buf[0..]);

    try expectError(error.BadMessage, MessageType.read(&breader));
}

// TODO: byzantine errors and state machine disorder

//
// Imports
//

comptime {
    _ = @import("protocol/Depart.zig");
    _ = @import("protocol/EntryRequest.zig");
    _ = @import("protocol/Message.zig");
}

// EOF
