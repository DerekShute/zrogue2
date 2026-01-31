//!
//! Handshake response
//!

const std = @import("std");
const HandshakeRequest = @import("HandshakeRequest.zig");

const net = std.net;
const Writer = std.io.Writer;
const Reader = std.io.Reader;

const Self = @This();

pub const Code = enum {
    awaiting_entry, // will wait for next message in state machine
    rejected,
    bad_version,
};

// Do not provide default values (not even 'undefined') because we want to
// detect non-present fields in the JSON parse

server_version: u32,
nonce: u32,
code: Code,

//
// Methods
//

pub fn init(version: u32, nonce: u32, code: Code) Self {
    return .{
        .server_version = version,
        .nonce = nonce,
        .code = code,
    };
}

pub fn send(self: Self, writer: *Writer, allocator: std.mem.Allocator) !void {
    var buffer = std.io.Writer.Allocating.init(allocator);
    defer buffer.deinit();

    try buffer.writer.print("{f}\n", .{std.json.fmt(self, .{})});
    try writer.writeAll(buffer.written());
    try writer.flush();
}

pub fn receive(reader: *Reader, allocator: std.mem.Allocator) !Self {
    const msg = try reader.takeDelimiterInclusive('\n');
    const parsed = try std.json.parseFromSlice(Self, allocator, msg, .{});
    defer parsed.deinit();

    return parsed.value;
}

//
// Unit Testing
//
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "send response read response" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    var sresp = init(100, 1000, .awaiting_entry);

    try sresp.send(&bwriter, std.testing.allocator);

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    const resp = try receive(&breader, std.testing.allocator);
    try expectEqual(resp.server_version, sresp.server_version);
    try expectEqual(resp.nonce, sresp.nonce);
}

test "read bad response" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll("This is not valid JSON\n");
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.SyntaxError,
        receive(&breader, std.testing.allocator),
    );
}

test "read short response" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    var sresp = init(10, 1000, .awaiting_entry);
    try sresp.send(&bwriter, std.testing.allocator);

    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);
    try expectError(
        error.EndOfStream,
        receive(&breader, std.testing.allocator),
    );
}

test "read wrong json resp" {
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
        receive(&breader, std.testing.allocator),
    );
}

test "read resp missing field" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"nonce":1}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.MissingField,
        receive(&breader, std.testing.allocator),
    );
}

test "read resp bad code" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"code":"awaiting_flapdoodle"}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.InvalidEnumTag,
        receive(&breader, std.testing.allocator),
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
        receive(&breader, std.testing.allocator),
    );
}

test "read resp added field" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"server_version":1,"nonce":20,"code":"awaiting_entry","frotz":37}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.UnknownField,
        receive(&breader, std.testing.allocator),
    );
}

// TODO: excessively long response

// EOF
