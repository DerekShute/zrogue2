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

pub const Depart = @import("protocol/Depart.zig");
pub const EntryRequest = @import("protocol/EntryRequest.zig");

//
// Constants
//

pub const max_player_name_length = EntryRequest.max_name_len;

//
// Errors, to purify the raw error results
//

pub const Error = error{
    BadMessage,
    ConnectionDropped,
    SendError,
    UnexpectedError,
};

//
// Service Routines
//

fn WrapRead(comptime T: type) *const fn (std.mem.Allocator, *Reader) Error!*T {
    return struct {
        fn read(allocator: std.mem.Allocator, reader: *Reader) !*T {
            const m = T.read(reader, allocator) catch |err| switch (err) {
                error.EndOfStream => return Error.ConnectionDropped,
                error.InvalidFormat => return Error.BadMessage, // not msgpack, etc.
                error.OutOfMemory => return Error.BadMessage, // Too long, etc.
                error.UnknownStructField => return Error.BadMessage,
                else => return Error.UnexpectedError,
            };
            return m;
        }
    }.read;
}

fn WrapWrite(comptime T: type) *const fn (*T, *Writer) Error!void {
    return struct {
        fn write(self: *T, writer: *Writer) !void {
            self.write(writer) catch |err| switch (err) {
                error.WriteFailed => return Error.SendError,
                else => return Error.UnexpectedError,
            };
        }
    }.write;
}

//
// Public Routines
//

// Entry Request

pub const readEntryRequest = WrapRead(EntryRequest);

pub fn writeEntryRequest(
    writer: *Writer,
    name: []const u8,
) !void {
    const rawWrite = WrapWrite(EntryRequest);

    var alloc_b: [30]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = EntryRequest.init(fba.allocator(), name) catch unreachable;
    defer msg.deinit(fba.allocator());

    // TODO: write identifier

    try rawWrite(msg, writer);
}

// Depart

pub const readDepart = WrapRead(Depart);

pub fn writeDepart(
    writer: *Writer,
    message: []const u8,
) !void {
    const rawWrite = WrapWrite(Depart);

    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    var msg = Depart.init(fba.allocator(), message) catch unreachable;
    defer msg.deinit(fba.allocator());

    // TODO: write identifier

    try rawWrite(msg, writer);
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

    const req = try readEntryRequest(std.testing.allocator, &breader);
    defer req.deinit(std.testing.allocator);

    try expect(std.mem.eql(u8, req.name, "frammitzor"));

    bwriter = std.io.Writer.fixed(&buffer); // Reset

    // TODO: other transactions

    try writeDepart(&bwriter, "client is disconnecting");

    breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    const depart = try readDepart(std.testing.allocator, &breader);
    defer depart.deinit(std.testing.allocator);

    try expect(std.mem.eql(u8, depart.message, "client is disconnecting"));
}

// TODO: byzantine errors and state machine disorder

//
// Imports
//

comptime {
    _ = @import("protocol/Depart.zig");
    _ = @import("protocol/EntryRequest.zig");
}

// EOF
