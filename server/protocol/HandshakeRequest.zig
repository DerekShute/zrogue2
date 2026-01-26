//!
//! Handshake request and response
//!

const std = @import("std");
const util = @import("util.zig");

const Writer = std.io.Writer;
const Reader = std.io.Reader;

const Self = @This();

// Do not provide default values (not even 'undefined') because we want to
// detect non-present fields in the JSON parse

client_version: u32,
// TODO: min server version
signature: u32,
nonce: u32,

//
// Methods
//

pub fn init(version: u32, nonce: u32) Self {
    return .{
        .client_version = version,
        .signature = util.SIGNATURE,
        .nonce = nonce,
    };
}

pub fn send(self: Self, writer: *Writer, allocator: std.mem.Allocator) !void {
    var buffer = std.io.Writer.Allocating.init(allocator); // TODO rid
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

test "send request read request" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    var sendreq = init(100, 1000);
    try sendreq.send(&bwriter, std.testing.allocator);

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    const req = try receive(&breader, std.testing.allocator);
    try expectEqual(req.client_version, sendreq.client_version);
    try expectEqual(req.signature, util.SIGNATURE);
    try expectEqual(req.nonce, sendreq.nonce);
}

test "read bad request" {
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

test "read short request" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    var sendreq = init(10, 100);
    try sendreq.send(&bwriter, std.testing.allocator);

    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);
    try expectError(
        error.EndOfStream,
        receive(&breader, std.testing.allocator),
    );

    // TODO this doesn't truncate the input, but of the stream
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
        receive(&breader, std.testing.allocator),
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
        receive(&breader, std.testing.allocator),
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
        receive(&breader, std.testing.allocator),
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
        receive(&breader, std.testing.allocator),
    );
}

// TODO: excessively long request

// EOF
