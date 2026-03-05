//!
//! Remote access to/from zrogue server
//!

const std = @import("std");
const msgpack = @import("msgpack");

const server = @import("root.zig"); // TODO this is recursive

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;
const MessageType = server.MessageType;

pub const Action = @import("protocol/Action.zig");
pub const Depart = @import("protocol/Depart.zig");
pub const EntryRequest = @import("protocol/EntryRequest.zig");
pub const MapUpdate = @import("protocol/MapUpdate.zig");
pub const Message = @import("protocol/Message.zig");
pub const TableUpdate = @import("protocol/TableUpdate.zig");

const Self = @This();

//
// Types
//

pub const Dispatch = struct {
    cb: *const fn (conn: *Self, ctx: *anyopaque) void,
};

// const rig = [_]Dispatch{
//    .{ .cb = doThing },
//
//    required size via MessageType.count
//
//    ...,
// };

pub const State = enum {
    init,
    connected,
    closing,
};

//
// Members
//

reader: *Reader = undefined,
writer: *Writer = undefined,
sm: ?[MessageType.count]Dispatch = null,
state: State = .init,
name: []const u8 = undefined,

//
// Messaging wrapper
//

fn Wrap(comptime T: type, comptime MT: MessageType) type {
    return struct {
        //
        //
        pub fn receive(self: *Self, allocator: Allocator) !void {
            const buffer = try allocator.alloc(u8, 325);
            defer allocator.free(buffer);
            var fba = std.heap.FixedBufferAllocator.init(buffer);
            // Abandon this allocator...handled by the buffer free

            var msg = try msgpack.decode(T, fba.allocator(), self.reader);
            if (!msg.value.valid()) {
                return error.Invalid;
            }

            if (self.sm) |sm| {
                const act = sm[@intFromEnum(MT)];
                act.cb(self, &msg.value);
            }
        }
        //
        // TODO: incoming allocator
        pub fn write(self: *Self, text: []const u8) !void {
            var alloc_b: [100]u8 = undefined; // Calculated
            var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
            const allocator = fba.allocator();

            var msg = try T.init(allocator, text);
            defer msg.deinit(allocator);

            try MessageType.write(MT, self.writer);
            // TODO: write size of message
            try msgpack.encode(msg, self.writer);
            try self.writer.flush();
        }
    };
}

const receiveAction = Wrap(Action, .action).receive;
const receiveDepart = Wrap(Depart, .depart).receive;
const receiveEntryRequest = Wrap(EntryRequest, .entry_request).receive;
const receiveMapUpdate = Wrap(MapUpdate, .map_update).receive;
const receiveMessage = Wrap(Message, .message).receive;
const receiveTableUpdate = Wrap(TableUpdate, .table_update).receive;

// Dispatch

fn dispatch(self: *Self, allocator: Allocator) !void {
    // TODO: test for length of sm array?

    const mt = try server.MessageType.read(self.reader);
    try switch (mt) {
        .action => self.receiveAction(allocator),
        .depart => self.receiveDepart(allocator),
        .entry_request => self.receiveEntryRequest(allocator),
        .map_update => self.receiveMapUpdate(allocator),
        .message => self.receiveMessage(allocator),
        .table_update => self.receiveTableUpdate(allocator),
    };
}

//
// Interface
//

pub fn setState(self: *Self, state: State) void {
    self.state = state;
}

pub fn getState(self: *Self) State {
    return self.state;
}

pub fn run(self: *Self, allocator: Allocator) void {
    dispatch(self, allocator) catch {
        self.setState(.closing);
    };
}

//
// TODO: comptime / duck-typing trick?
//

pub fn writeAction(self: *Self, kind: Action.Kind, pos: []const i16) !void {
    var alloc_b: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    var msg = Action.init(fba.allocator(), kind, pos) catch unreachable;
    defer msg.deinit(fba.allocator());
    try MessageType.write(.action, self.writer);
    try msg.write(self.writer);
}

pub const writeDepart = Wrap(Depart, .depart).write;

pub fn writeMapUpdate(self: *Self, pos: []const i16, tile: MapUpdate.DisplayTile) !void {
    var alloc_b: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    var msg = MapUpdate.init(fba.allocator(), pos, tile) catch unreachable;
    defer msg.deinit(fba.allocator());
    try MessageType.write(.map_update, self.writer);
    try msg.write(self.writer);
}

pub const writeMessage = Wrap(Message, .message).write;
pub const writeEntryRequest = Wrap(EntryRequest, .entry_request).write;

pub fn writeTableUpdate(self: *Self, table: []const u8, entry: []const u8, value: []const u8) !void {
    var alloc_b: [200]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    var msg = TableUpdate.init(fba.allocator(), table, entry, value) catch unreachable;
    defer msg.deinit(fba.allocator());
    try MessageType.write(.table_update, self.writer);
    try msg.write(self.writer);
}

//
// Formatter
//

pub fn format(self: Self, w: *Writer) Writer.Error!void {
    return w.print("{s}", .{self.name});
}

//
// Unit Testing
//

const expect = std.testing.expect;

var hit: bool = false; // Testing instrumentation

fn testEntry(remote: *Self, ptr: *anyopaque) void {
    _ = remote;
    const msg: *server.EntryRequest = @ptrCast(@alignCast(ptr));
    expect(std.mem.eql(u8, msg.name, "frammitzor")) catch {
        @panic("test failure"); // No error return possible
    };
    hit = true;
}

fn testNoHit(remote: *Self, ptr: *anyopaque) void {
    _ = remote;
    _ = ptr;
    @panic("test failure"); // No error return possible
}

const test_rig = [_]Dispatch{
    .{ .cb = testNoHit }, // action
    .{ .cb = testNoHit }, // depart
    .{ .cb = testEntry }, // entry_request
    .{ .cb = testNoHit }, // map_update
    .{ .cb = testNoHit }, // message
    .{ .cb = testNoHit }, // table_update
};

test "basic usage" {
    var buffer: [128]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    var breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);

    var client = Self{
        .name = "whatever",
        .reader = &breader,
        .writer = &bwriter,
        .sm = test_rig,
    };

    try client.writeEntryRequest("frammitzor");

    // Dirty trick

    breader = std.io.Reader.fixed(buffer[0..bwriter.buffered().len]);
    client.reader = &breader;

    try expect(try MessageType.read(&breader) == .entry_request);
    try client.receiveEntryRequest(std.testing.allocator);

    try expect(hit);
}

// EOF
