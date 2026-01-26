//!
//! Handshake request and response
//!

const std = @import("std");
const net = std.net;
const Writer = std.io.Writer;
const Reader = std.io.Reader;

//
// Constants
//

const PROTOCOL_VERSION: u32 = 1;
const SIGNATURE: u32 = 0xFEEDBEEF;

// Do not provide default values (not even 'undefined') because we want to
// detect non-present fields in the JSON parse

pub const Request = struct {
    client_version: u32,
    // TODO: min server version
    signature: u32,
    nonce: u32,
};

pub const Response = struct {
    pub const Code = enum {
        awaiting_entry, // will wait for next message in state machine
        rejected,
        bad_version,
    };

    server_version: u32,
    signature: u32,
    nonce: u32,
    code: Code,
};

//
// Handshake Requests
//

pub fn sendReq(writer: *Writer, allocator: std.mem.Allocator) !void {
    var buffer = std.io.Writer.Allocating.init(allocator);
    defer buffer.deinit();

    const req = Request{
        .client_version = PROTOCOL_VERSION,
        .signature = SIGNATURE,
        .nonce = 1, // TODO canonical but need other answer
    };
    try buffer.writer.print("{f}\n", .{std.json.fmt(req, .{})});
    try writer.writeAll(buffer.written());
    try writer.flush();
}

pub fn readReq(reader: *Reader, allocator: std.mem.Allocator) !Request {
    const msg = try reader.takeDelimiterInclusive('\n');
    const parsed = try std.json.parseFromSlice(Request, allocator, msg, .{});
    defer parsed.deinit();

    return parsed.value;
}

//
// HandshakeResponse
//

pub fn sendResp(
    writer: *Writer,
    allocator: std.mem.Allocator,
    hs: Request,
    code: Response.Code,
) !void {
    var buffer = std.io.Writer.Allocating.init(allocator);
    defer buffer.deinit();

    const resp = Response{
        .server_version = PROTOCOL_VERSION,
        .signature = SIGNATURE,
        .nonce = hs.nonce,
        .code = code,
    };
    try buffer.writer.print("{f}\n", .{std.json.fmt(resp, .{})});
    try writer.writeAll(buffer.written());
    try writer.flush();
}

pub fn readResp(reader: *Reader, allocator: std.mem.Allocator) !Response {
    const msg = try reader.takeDelimiterInclusive('\n');
    const parsed = try std.json.parseFromSlice(Response, allocator, msg, .{});
    defer parsed.deinit();

    return parsed.value;
}

//
// Unit Testing
//
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

//
// Request testing
//

test "send request read request" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try sendReq(&bwriter, std.testing.allocator);

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    const req = try readReq(&breader, std.testing.allocator);
    try expectEqual(req.client_version, PROTOCOL_VERSION);
    try expectEqual(req.signature, SIGNATURE);
    try expectEqual(req.nonce, 1); // TODO canonical
}

test "read bad request" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll("This is not valid JSON\n");
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.SyntaxError,
        readReq(&breader, std.testing.allocator),
    );
}

test "read short request" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    try sendReq(&bwriter, std.testing.allocator);

    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);
    try expectError(
        error.EndOfStream,
        readReq(&breader, std.testing.allocator),
    );
}

test "read wrong json req" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"client_blershion":1}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.UnknownField,
        readReq(&breader, std.testing.allocator),
    );
}

test "read req missing field" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"signature":4276993775,"nonce":1}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.MissingField,
        readReq(&breader, std.testing.allocator),
    );
}

test "read req bad type" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"client_version":"flapdoodle"}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.InvalidCharacter,
        readReq(&breader, std.testing.allocator),
    );
}

test "read req add field" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"client_version":1,"signature":4276993775,"nonce":1,"phony":37}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.UnknownField,
        readReq(&breader, std.testing.allocator),
    );
}

// TODO: excessively long request

//
// Response testing
//

test "send response read response" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const req = Request{
        .client_version = PROTOCOL_VERSION,
        .signature = SIGNATURE,
        .nonce = 20,
    };

    try sendResp(&bwriter, std.testing.allocator, req, .awaiting_entry);

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    const resp = try readResp(&breader, std.testing.allocator);
    try expectEqual(resp.server_version, PROTOCOL_VERSION);
    try expectEqual(resp.signature, SIGNATURE);
    try expectEqual(resp.nonce, 20); // Request's nonce
}

test "read bad response" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll("This is not valid JSON\n");
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.SyntaxError,
        readResp(&breader, std.testing.allocator),
    );
}

test "read short response" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const req = Request{
        .client_version = PROTOCOL_VERSION,
        .signature = SIGNATURE,
        .nonce = 1,
    };
    try sendResp(&bwriter, std.testing.allocator, req, .awaiting_entry);

    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);
    try expectError(
        error.UnexpectedEndOfInput,
        readResp(&breader, std.testing.allocator),
    );
}

test "read wrong json resp" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"client_blershion":1,"signature":4276993775,"nonce":1}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.UnknownField,
        readResp(&breader, std.testing.allocator),
    );
}

test "read resp missing field" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"signature":4276993775,"nonce":1}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.MissingField,
        readResp(&breader, std.testing.allocator),
    );
}

test "read resp bad code" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"server_version":1,"code":"awaiting_flapdoodle"}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.InvalidEnumTag,
        readResp(&breader, std.testing.allocator),
    );
}

test "read resp bad type" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"server_version":"floop"}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.InvalidCharacter,
        readResp(&breader, std.testing.allocator),
    );
}

test "read resp added field" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"server_version":1,"signature":4276993775,"nonce":20,"code":"awaiting_entry","frotz":37}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.UnknownField,
        readResp(&breader, std.testing.allocator),
    );
}

// TODO: excessively long response

// EOF
