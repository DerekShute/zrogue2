//!
//! Action placeholder
//!
//! TODO: need to integrate, etc. with roguelib/Action.zig
//!

const std = @import("std");
const msgpack = @import("msgpack");
const utils = @import("utils.zig");

const Reader = std.io.Reader;
const Writer = std.io.Writer;
const Allocator = std.mem.Allocator;

const Self = @This();

pub const Kind = enum {
    none,
    quit,
    ascend,
    descend,
    move, // Directional
    search,
    take, // Positional
    wait,
};

kind: Kind,
x: i16, // As slice/array is a problem
y: i16,

// EOF

pub fn init(allocator: Allocator, kind: Kind, pos: []const i16) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.kind = kind;
    s.x = pos[0];
    s.y = pos[1];
    return s;
}

pub fn copy(allocator: Allocator, basis: Self) !*Self {
    return Self.init(allocator, basis.kind, &.{ basis.x, basis.y });
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.destroy(self);
}

pub fn valid(self: *Self) bool {
    _ = self;
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
// Unit Tests
//
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;

test "write and read" {
    var buffer: [256]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var sendmsg = try init(t_allocator, .quit, &.{ 0, 1 });
    defer sendmsg.deinit(t_allocator);

    try expect(valid(sendmsg));

    try sendmsg.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    var msg = try read(&breader, t_allocator);
    defer msg.deinit(t_allocator);

    try expect(msg.kind == sendmsg.kind);
    try expect(msg.x == sendmsg.x);
    try expect(msg.y == sendmsg.y);
}

// EOF
