//!
//! Handshake request and response
//!

const std = @import("std");

const Writer = std.io.Writer;
const Reader = std.io.Reader;

const Self = @This();

// Do not provide default values (not even 'undefined') because we want to
// detect non-present fields in the JSON parse

client_version: u32,
nonce: u32,

//
// Methods
//

pub fn init(version: u32, nonce: u32) Self {
    return .{
        .client_version = version,
        .nonce = nonce,
    };
}

pub fn send(self: Self, writer: *Writer) !void {
    var buffer: [36]u8 = undefined; // Predetermined to fit
    var bwriter = std.io.Writer.fixed(&buffer);

    bwriter.print("{f}\n", .{std.json.fmt(self, .{})}) catch |err| switch (err) {
        // WriteFailed: buffer too small.  Recalculate it!
        error.WriteFailed => @panic("HandshakeRequest.send buffer too small"),
        else => return err,
    };
    try writer.writeAll(bwriter.buffered());
    try writer.flush();
}

pub fn receive(reader: *Reader) !Self {
    var alloc_b: [200]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);

    const msg = try reader.takeDelimiterInclusive('\n');
    const parsed = try std.json.parseFromSlice(Self, fba.allocator(), msg, .{});
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
    try sendreq.send(&bwriter);

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    const req = try receive(&breader);
    try expectEqual(req.client_version, sendreq.client_version);
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
        receive(&breader),
    );
}

test "read truncated stream req" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    var sendreq = init(10, 100);
    try sendreq.send(&bwriter);

    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);
    try expectError(
        error.EndOfStream,
        receive(&breader),
    );
}

test "read incomplete json req" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"client_version":100,"nonce":
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    // Never completes the thought
    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len + 5]);
    try expectError(
        error.UnexpectedEndOfInput,
        receive(&breader),
    );
}

test "read wrong json req" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"flapdoodle":1}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.UnknownField,
        receive(&breader),
    );
}

test "read req missing field" {
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
        receive(&breader),
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
        receive(&breader),
    );
}

test "read req added field" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll(
        \\{"client_version":1,"nonce":1,"phony":37}
    );
    try bwriter.print("\n", .{});
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(
        error.UnknownField,
        receive(&breader),
    );
}

// TODO JSON is too long or something

// EOF
