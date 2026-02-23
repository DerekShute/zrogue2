//!
//! Entry Request - player introduction into game
//!
//!   name : max 32 characters (arbitrary)
//!

const std = @import("std");
const utils = @import("utils.zig");

const Reader = std.io.Reader;
const Writer = std.io.Writer;
const Allocator = std.mem.Allocator;

const Self = @This();

pub const max_namelen = 32;

//
// Members: do not supply defaults!
//

name: []u8,
// TODO: class, race, ...

//
// Lifecycle
//

pub fn copy(allocator: Allocator, basis: Self) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.name = try allocator.dupe(u8, basis.name);
    return s;
}

pub fn init(allocator: Allocator, name: []const u8) !*Self {
    if (name.len > max_namelen) {
        @panic("EntryRequest.init: name too long"); // Prevent this, please
    }
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.name = try allocator.dupe(u8, name);
    return s;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
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

pub fn read(reader: *Reader, allocator: Allocator) !*Self {
    return utils.genericRead(Self, reader, allocator);
}

//
// Unit Testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const msgpack = @import("msgpack");
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;

const test_name: *const [max_namelen:0]u8 = "*" ** max_namelen;

test "send request read request" {
    // Beyond the allocation scheme: if this fails, testing must be reworked
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 2 });
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var sendreq = try init(t_allocator, test_name);
    defer sendreq.deinit(t_allocator);

    try sendreq.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    var req = try read(&breader, f.allocator());
    defer req.deinit(f.allocator());

    try expect(std.mem.eql(u8, req.name, test_name));
}

test "send request memory failure 1" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

test "send request memory failure 2" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 1 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

// receive

test "receive request memory failure" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 1 });
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var sendreq = try init(t_allocator, "frammitz");
    defer sendreq.deinit(t_allocator);

    try sendreq.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    try expectError(error.OutOfMemory, read(&breader, f.allocator()));
}

// "send name too long" protected by a panic in init(), so handcraft

test "receive EntryRequest fails validation (name size)" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    const sname = "*" ** 33;

    const name = try t_allocator.dupe(u8, sname);
    defer t_allocator.free(name);

    const sendreq: Self = .{
        .name = name,
    };
    try msgpack.encode(sendreq, &bwriter);
    try bwriter.flush();

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    try expectError(error.Invalid, read(&breader, t_allocator));
}

// EOF
