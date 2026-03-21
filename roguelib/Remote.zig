//!
//! Remote access to/from zrogue server
//!

const std = @import("std");
const msgpack = @import("msgpack");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const Self = @This();

//
// Types
//

pub const Error = error{
    Failed,
    Invalid,
};

pub const State = enum {
    init,
    connected,
    closing,
};

pub const DispatchFn = *const fn (conn: *Self, allocator: Allocator) Error!void;
pub const ReadFn = *const fn (ctx: *anyopaque, ptr: *anyopaque) Error!void;

// const rig = [_]DispatchFn{
//    doThing,  (message 0)...
//    ...,
// };

//
// Members
//

ctx: *anyopaque = undefined,
reader: *Reader = undefined,
writer: *Writer = undefined,
sm: []const DispatchFn = undefined,
state: State = .init,

//
// Messaging wrappers
//

pub fn Write(comptime T: type, comptime MT: u16) type {
    // You can return the function body as '.write' here but that makes the
    // return type very complicated.
    return struct {
        pub fn write(self: *Self, msg: T) !void {
            var intbuf: [2]u8 = undefined;
            std.mem.writeInt(u16, &intbuf, MT, .big);
            try self.writer.writeAll(intbuf[0..]);
            // TODO: write size of message - need to encode it
            try msgpack.encode(msg, self.writer);
            try self.writer.flush();
        }
    };
}

pub fn Dispatch(comptime T: type, comptime FN: ReadFn) type {
    return struct {
        // NOTE: allocator is fixed buffer or arena and must be squashed
        pub fn dispatch(self: *Self, allocator: Allocator) !void {
            var msg = msgpack.decode(T, allocator, self.reader) catch {
                return error.Failed;
            };
            defer msg.deinit();

            if (!msg.value.valid()) {
                return error.Invalid;
            }

            FN(self.ctx, &msg.value) catch return error.Failed;
        }
    };
}

//
// Interface
//

pub fn run(self: *Self, allocator: Allocator) !void {
    const buffer = try allocator.alloc(u8, 325);
    defer allocator.free(buffer);
    var fba = std.heap.FixedBufferAllocator.init(buffer);
    // fba abandoned when its buffer is freed

    var int: [2]u8 = undefined;
    try self.reader.readSliceAll(&int);
    const val = std.mem.readInt(u16, &int, .big);
    if (val >= self.sm.len) {
        return error.InvalidType;
    }

    const cb = self.sm[val];
    try cb(self, fba.allocator());
}

//
// Unit Testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;

const Test = struct {
    int: u16,

    pub fn valid(self: Test) bool {
        if (self.int == 0xdead) {
            return false;
        }
        return true;
    }
};

const TestExtra = struct {
    int: u16,
    j: u16,

    pub fn valid(self: TestExtra) bool {
        _ = self;
        return true;
    }
};

fn testEntry(ctx: *anyopaque, ptr: *anyopaque) !void {
    _ = ctx;
    _ = ptr;
}

const testWrite = Write(Test, 0).write;
const testWriteExtra = Write(TestExtra, 0).write;

const test_rig = [_]DispatchFn{
    Dispatch(Test, testEntry).dispatch, // 0
};

test "basic usage" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var client = Self{
        // TODO: ctx unhandled
        .reader = &breader,
        .writer = &bwriter,
        .sm = &test_rig,
    };

    try testWrite(&client, .{ .int = 1 });

    // Dirty trick
    breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    client.reader = &breader;

    try client.run(t_allocator);
}

test "internal validation" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var client = Self{
        .reader = &breader,
        .writer = &bwriter,
        .sm = &test_rig,
    };

    try testWrite(&client, .{ .int = 0xdead });

    // Dirty trick
    breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    client.reader = &breader;

    try expectError(error.Invalid, client.run(t_allocator));
}

test "invalid message type" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var client = Self{
        .reader = &breader,
        .writer = &bwriter,
        .sm = &test_rig, // unused
    };

    var intbuf: [2]u8 = undefined;
    std.mem.writeInt(u16, &intbuf, 100, .big);
    try bwriter.writeAll(intbuf[0..]);
    // (nothing else is read)

    // Dirty trick
    breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    client.reader = &breader;

    try expectError(error.InvalidType, client.run(t_allocator));
}

test "truncated input" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var client = Self{
        .reader = &breader,
        .writer = &bwriter,
        .sm = &test_rig,
    };

    try testWrite(&client, .{ .int = 1 });

    // Dirty trick
    breader = Reader.fixed(buffer[0 .. bwriter.buffered().len - 5]);
    client.reader = &breader;

    // EndOfStream, translated
    try expectError(error.Failed, client.run(t_allocator));
}

test "added field" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var client = Self{
        .reader = &breader,
        .writer = &bwriter,
        .sm = &test_rig,
    };

    try testWriteExtra(&client, .{ .int = 1, .j = 2 });

    // Dirty trick
    breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    client.reader = &breader;

    // UnknownStructField, translated
    try expectError(error.Failed, client.run(t_allocator));
}

//
// Not really interested in being exhaustive about this
//
// 'error.ReadFailed' 'error.OutOfMemory' 'error.NoSpaceLeft'
// 'error.IntegerOverflow' 'error.Null'
// 'error.InvalidFormat' : not msgpack
// 'error.MissingStructFields'
//

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
