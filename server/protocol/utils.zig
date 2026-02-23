//!
//! messaging utilities
//!

const std = @import("std");
const msgpack = @import("msgpack");

const Reader = std.io.Reader;
const Writer = std.io.Writer;
const Allocator = std.mem.Allocator;

// Use a constrained allocator here to prevent malicious actors: they
// can't send a messagepack-bomb if we won't accept it.

// The buffer sizes are calculated to handle the max reasonable message, and
// a test here should reflect that.

pub fn genericWrite(msg: anytype, writer: *Writer) !void {
    var buffer: [325]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    try msgpack.encode(msg, &bwriter);
    try writer.writeAll(bwriter.buffered());
    try writer.flush();
}

pub fn genericRead(T: type, reader: *Reader, allocator: Allocator) !*T {
    var buffer: [325]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    // error.OutOfMemory -> message (including internal strings) is too long

    var msg = try msgpack.decode(T, fba.allocator(), reader);
    errdefer msg.deinit();

    if (!msg.value.valid()) { // Borderline but enforce
        return error.Invalid;
    }
    return try T.copy(allocator, msg.value);
}

//
// Unit Testing
//
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const test_str = "this is a test";

const TestStruct = struct {
    //
    // Testing struture to prove stuff
    //
    // Note that if you give default values, even 'undefined', decode will
    // supply those defaults.
    //

    string: []u8,
    int1: i32,

    const Self = @This();

    pub fn copy(allocator: Allocator, basis: Self) !*Self {
        const s: *Self = try allocator.create(Self);
        errdefer allocator.destroy(s);
        s.string = try allocator.dupe(u8, basis.string);
        s.int1 = basis.int1;
        return s;
    }

    pub fn init(allocator: Allocator, str: []const u8, val: i32) !*Self {
        const s: *Self = try allocator.create(Self);
        errdefer allocator.destroy(s);
        s.string = try allocator.dupe(u8, str);
        s.int1 = val;
        return s;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.string);
        allocator.destroy(self);
    }

    pub fn valid(self: *Self) bool {
        if (self.int1 == 0) { // Completely phony easy case
            return false;
        }
        return true;
    }

    pub const write = genericWrite;

    pub fn read(reader: *Reader, allocator: Allocator) !*Self {
        return genericRead(Self, reader, allocator);
    }
};

// boring use case

test "write and read" {
    var buffer: [100]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var msg = try TestStruct.init(t_allocator, test_str, 4029);
    defer msg.deinit(t_allocator);

    try msg.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    var rmsg = try TestStruct.read(&breader, std.testing.allocator);
    defer rmsg.deinit(t_allocator);

    try expect(std.mem.eql(u8, rmsg.string, msg.string));
    try expect(rmsg.int1 == msg.int1);
}

// write

test "WriteFailed" {
    var buffer: [20]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var send = try TestStruct.init(t_allocator, test_str, 4000);
    defer send.deinit(t_allocator);

    try expectError(error.WriteFailed, send.write(&bwriter));
}

// read

test "receive message truncated EndOfStream" {
    var buffer: [100]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var send = try TestStruct.init(t_allocator, test_str, 2041);
    defer send.deinit(t_allocator);

    try send.write(&bwriter);
    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);
    try expectError(error.EndOfStream, TestStruct.read(&breader, t_allocator));
}

test "received message fails validation" {
    var buffer: [100]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var send = try TestStruct.init(t_allocator, test_str, 0);
    defer send.deinit(t_allocator);

    try send.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.Invalid, TestStruct.read(&breader, t_allocator));
}

test "receive message too large" {
    // This test also captures the largest message supported

    var buffer: [2000]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    const too_long: *const [300:0]u8 = "*" ** 300;

    var send = try TestStruct.init(t_allocator, too_long, 4029);
    defer send.deinit(t_allocator);

    try send.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.OutOfMemory, TestStruct.read(&breader, t_allocator));
}

test "receive incorrect message" {
    const Other = struct {
        f1: u32 = 1024,
        f2: f64 = 10.473,
    };
    const other = Other{};

    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    try msgpack.encode(other, &bwriter);
    try bwriter.flush();

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.UnknownStructField, TestStruct.read(&breader, t_allocator));
}

test "missing field in received message" {
    const Other = struct {
        string: []u8 = undefined,
    };
    var other = Other{};

    other.string = try t_allocator.dupe(u8, "frotz");
    defer t_allocator.free(other.string);

    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    try msgpack.encode(other, &bwriter);
    try bwriter.flush();

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.MissingStructFields, TestStruct.read(&breader, t_allocator));
}

// This depends on how the messages are packed and unpacked.  Do we care?
// As it stands the packing is by field name, not index.  So ordering is
// not enforced either.

test "renamed field in received message" {
    const Other = struct {
        string: []u8 = undefined,
        not_int1: i32 = 1024,
    };
    var other = Other{};

    other.string = try t_allocator.dupe(u8, "frotz");
    defer t_allocator.free(other.string);

    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    try msgpack.encode(other, &bwriter);
    try bwriter.flush();

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.UnknownStructField, TestStruct.read(&breader, t_allocator));
}

test "receive message is not msgpack" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    try bwriter.writeAll("This is not valid messagepack");
    try bwriter.flush();

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.InvalidFormat, TestStruct.read(&breader, t_allocator));
}

test "additional field in received message" {
    const Other = struct {
        string: []u8 = undefined,
        int1: i32 = 1024,
        frotz: i32 = 10,
    };
    var other = Other{};

    other.string = try t_allocator.dupe(u8, "frotz");
    defer t_allocator.free(other.string);

    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    try msgpack.encode(other, &bwriter);
    try bwriter.flush();

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.UnknownStructField, TestStruct.read(&breader, t_allocator));
}
// EOF
