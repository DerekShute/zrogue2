//!
//! Server library stashed here for convenience.  Import on client side
//!
//! Transaction:
//!
//!    HANDSHAKE_REQUEST json ->
//!                  <- HANDSHAKE_RESPONSE json
//!    ENTRY msgpack ->
//!     (TODO)

const std = @import("std");
const Writer = std.io.Writer;
const Reader = std.io.Reader;

pub const HandshakeRequest = @import("protocol/HandshakeRequest.zig");
pub const HandshakeResponse = @import("protocol/HandshakeResponse.zig");

// TODO for now a given
pub const PROTOCOL_VERSION = 1;

//
// Errors, to purify the raw error results
//

pub const Error = error{
    ConnectionDropped,
    BadMessage,
    UnexpectedError,
};

//
// Routines
//

pub fn startHandshake(writer: *Writer) Error!void {
    var req = HandshakeRequest.init(PROTOCOL_VERSION, 1); // TODO pass in
    req.send(writer) catch {
        return Error.UnexpectedError;
    };
}

pub fn receiveHandshakeReq(
    reader: *Reader,
    allocator: std.mem.Allocator,
) Error!HandshakeRequest {
    return HandshakeRequest.receive(reader, allocator) catch |err| {
        return switch (err) {
            error.EndOfStream => Error.ConnectionDropped,
            error.UnexpectedEndOfInput => Error.BadMessage,
            else => Error.UnexpectedError,
        };
    };
}

pub fn sendHandshakeResponse(
    writer: *Writer,
    nonce: u32,
    code: HandshakeResponse.Code,
) Error!void {
    var resp = HandshakeResponse.init(PROTOCOL_VERSION, nonce, code);
    resp.send(writer) catch {
        return Error.UnexpectedError;
    };
}

pub fn receiveHandshakeResponse(
    reader: *Reader,
    allocator: std.mem.Allocator,
) Error!HandshakeResponse {
    return HandshakeResponse.receive(reader, allocator) catch |err| {
        return switch (err) {
            error.EndOfStream => Error.ConnectionDropped,
            error.UnexpectedEndOfInput => Error.BadMessage,
            else => Error.UnexpectedError,
        };
    };
}

//
// Unit Testing
//
const expectError = std.testing.expectError;

test "Handshake sequence" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const allocator = std.testing.allocator;

    try startHandshake(&bwriter);

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    const req = try receiveHandshakeReq(&breader, allocator);

    bwriter = std.io.Writer.fixed(&buffer); // reset

    try sendHandshakeResponse(
        &bwriter,
        req.nonce,
        .awaiting_entry,
    );

    breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    _ = try receiveHandshakeResponse(&breader, allocator);
}

test "Handshake request disconnect" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const allocator = std.testing.allocator;

    try startHandshake(&bwriter);

    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);

    try expectError(
        Error.ConnectionDropped,
        receiveHandshakeReq(&breader, allocator),
    );
}

test "Handshake response disconnect" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const allocator = std.testing.allocator;

    try sendHandshakeResponse(
        &bwriter,
        1,
        .awaiting_entry,
    );

    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);

    try expectError(
        Error.ConnectionDropped,
        receiveHandshakeResponse(&breader, allocator),
    );
}

// Imports

comptime {
    _ = @import("protocol/HandshakeRequest.zig");
    _ = @import("protocol/HandshakeResponse.zig");
}

// EOF
