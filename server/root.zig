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

pub fn receiveHandshakeReq(reader: *Reader) Error!HandshakeRequest {
    return HandshakeRequest.receive(reader) catch |err| {
        return switch (err) {
            error.EndOfStream => Error.ConnectionDropped,
            error.InvalidCharacter => Error.BadMessage,
            error.MissingField => Error.BadMessage,
            error.SyntaxError => Error.BadMessage,
            error.UnexpectedEndOfInput => Error.BadMessage,
            error.UnknownField => Error.BadMessage,
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
) Error!HandshakeResponse {
    return HandshakeResponse.receive(reader) catch |err| {
        return switch (err) {
            error.EndOfStream => Error.ConnectionDropped,
            error.InvalidCharacter => Error.BadMessage,
            error.InvalidEnumTag => Error.BadMessage,
            error.MissingField => Error.BadMessage,
            error.UnexpectedEndOfInput => Error.BadMessage,
            error.UnknownField => Error.BadMessage,
            else => Error.UnexpectedError,
            // TODO others
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

    try startHandshake(&bwriter);

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    const req = try receiveHandshakeReq(&breader);

    bwriter = std.io.Writer.fixed(&buffer); // reset

    try sendHandshakeResponse(
        &bwriter,
        req.nonce,
        .awaiting_entry,
    );

    breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    _ = try receiveHandshakeResponse(&breader);
}

test "Handshake request disconnect" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try startHandshake(&bwriter);

    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);

    try expectError(
        Error.ConnectionDropped,
        receiveHandshakeReq(&breader),
    );
}

test "Handshake response disconnect" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try sendHandshakeResponse(
        &bwriter,
        1,
        .awaiting_entry,
    );

    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);

    try expectError(
        Error.ConnectionDropped,
        receiveHandshakeResponse(&breader),
    );
}

// Imports

comptime {
    _ = @import("protocol/HandshakeRequest.zig");
    _ = @import("protocol/HandshakeResponse.zig");
}

// EOF
