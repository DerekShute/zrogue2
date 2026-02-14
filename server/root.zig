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
//!                  <- DEPART msgpack
//!
//!                  <- ERROR msgpack
//!

const std = @import("std");
const Writer = std.io.Writer;
const Reader = std.io.Reader;

pub const EntryRequest = @import("protocol/EntryRequest.zig");

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
// Routines
//

//
// Entry Request
//

pub fn writeEntryRequest(
    writer: *Writer,
    name: []const u8,
) !void {
    var alloc_b: [30]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    var msg = EntryRequest.init(fba.allocator(), name) catch unreachable;

    // TODO: write identifier

    msg.write(writer) catch |err| switch (err) {
        error.WriteFailed => return Error.SendError,
        else => return Error.UnexpectedError,
    };
}

pub fn readEntryRequest(
    allocator: std.mem.Allocator,
    reader: *Reader,
) !*EntryRequest {
    // TODO: read identifier?  Or at above level?
    const msg = EntryRequest.read(reader, allocator) catch |err| switch (err) {
        error.EndOfStream => return Error.ConnectionDropped,
        error.InvalidFormat => return Error.BadMessage, // not msgpack, etc.
        error.OutOfMemory => return Error.BadMessage, // Too long, etc.
        error.UnknownStructField => return Error.BadMessage,
        else => return Error.UnexpectedError,
    };
    return msg;
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
}

test "request send fails" {
    var buffer: [20]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try writeEntryRequest(&bwriter, "frammitzor");
}

// TODO: byzantine errors and state machine disorder

//
// Imports
//

comptime {
    _ = @import("protocol/EntryRequest.zig");
}

// EOF
