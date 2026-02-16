//!
//! Entry Request - player introduction into game
//!
//!   name : max 32 characters (arbitrary)
//!

const std = @import("std");
const msgpack = @import("msgpack");
const utils = @import("utils.zig");

const Self = @This();

pub const max_namelen = 32;

//
// Members
//

// NOTE: there is no better way to do this.  Defining a static name
// buffer will complicate the encode/decode and the management of
// slice versus array buffer is twisting.

name: []u8 = undefined,
// TODO: class, race, ...

//
// Lifecycle
//

pub fn copy(allocator: std.mem.Allocator, basis: Self) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.name = try allocator.dupe(u8, basis.name);
    return s;
}

pub fn init(allocator: std.mem.Allocator, name: []const u8) !*Self {
    if (name.len > max_namelen) {
        @panic("EntryRequest.init: name too long"); // Prevent this, please
    }
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.name = try allocator.dupe(u8, name);
    return s;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.name);
    allocator.destroy(self);
}

pub fn valid(self: *Self) bool {
    if (self.name.len > max_namelen) { // Borderline but enforce
        return false;
    }
    return true;
}

//
// Methods
//

pub const write = utils.genericWrite;

pub fn read(reader: *std.io.Reader, allocator: std.mem.Allocator) !*Self {
    return utils.genericRead(Self, reader, allocator);
}

//
// Unit Testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "send request read request" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const name: *const [max_namelen:0]u8 = "*" ** max_namelen;

    var sendreq = try init(std.testing.allocator, name);
    defer sendreq.deinit(std.testing.allocator);

    try sendreq.write(&bwriter);
    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    var req = try read(&breader, std.testing.allocator);
    defer req.deinit(std.testing.allocator);

    try expect(std.mem.eql(u8, req.name, name));
}

test "send request memory failure 1" {
    var f = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{ .fail_index = 0 },
    );

    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

test "send request memory failure 2" {
    var f = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{ .fail_index = 1 },
    );

    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

test "send request WriteFailed" {
    var buffer: [20]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const name: *const [max_namelen:0]u8 = "*" ** max_namelen;

    var sendreq = try init(std.testing.allocator, name);
    defer sendreq.deinit(std.testing.allocator);

    try expectError(error.WriteFailed, sendreq.write(&bwriter));
}

// receive

test "receive request truncated" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const name: *const [max_namelen:0]u8 = "*" ** max_namelen;

    var sendreq = try init(std.testing.allocator, name);
    defer sendreq.deinit(std.testing.allocator);

    try sendreq.write(&bwriter);
    var breader = std.io.Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);
    try expectError(error.EndOfStream, read(&breader, std.testing.allocator));
}

test "receive request memory failure" {
    var f = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{ .fail_index = 1 },
    );
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    var sendreq = try init(std.testing.allocator, "frammitz");
    defer sendreq.deinit(std.testing.allocator);

    try sendreq.write(&bwriter);
    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    try expectError(error.OutOfMemory, read(&breader, f.allocator()));
}

test "receive request memory failure bound" {
    var f = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{ .fail_index = 2 },
    );
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    var sendreq = try init(std.testing.allocator, "frammitz");
    defer sendreq.deinit(std.testing.allocator);

    try sendreq.write(&bwriter);
    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    // index 2 is outside the expected allocation range.  If this fails
    // then something has changed

    const msg = try read(&breader, f.allocator());
    defer msg.deinit(f.allocator());
}

// "send name too long" protected by a panic in init(), so handcraft

test "receive name barely too long" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const sname = "*" ** 33;

    const name = try std.testing.allocator.dupe(u8, sname);
    defer std.testing.allocator.free(name);

    const sendreq: Self = .{
        .name = name,
    };
    try msgpack.encode(sendreq, &bwriter);
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.OutOfMemory, read(&breader, std.testing.allocator));
}

test "receive name much too long" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    const sname: []const u8 = "*********************************************";

    const name = try std.testing.allocator.dupe(u8, sname);
    defer std.testing.allocator.free(name);

    const sendreq: Self = .{
        .name = name,
    };
    try msgpack.encode(sendreq, &bwriter);
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.OutOfMemory, read(&breader, std.testing.allocator));
}

test "incorrect message" {
    const Other = struct {
        f1: u32 = 1024,
        f2: f64 = 10.473,
    };
    const other = Other{};

    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try msgpack.encode(other, &bwriter);
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.UnknownStructField, read(&breader, std.testing.allocator));
}

test "message includes an additional field" {
    const Other = struct {
        name: []u8 = undefined,
        f1: u32 = 1024,
    };
    var other = Other{};

    other.name = try std.testing.allocator.dupe(u8, "frotz");
    defer std.testing.allocator.free(other.name);

    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try msgpack.encode(other, &bwriter);
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.UnknownStructField, read(&breader, std.testing.allocator));
}

// TODO: received message is missing a field

test "receive message is not msgpack" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);

    try bwriter.writeAll("This is not valid messagepack");
    try bwriter.flush();

    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.InvalidFormat, read(&breader, std.testing.allocator));
}

// TODO: connection Dropped

// EOF
