//!
//! Protocol: write messages with headers etc, dispatch reads
//!

const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

const Self = @This();

//
// Types
//

pub const Error = error{
    Failed,
    Invalid,
    Departing, // Severing connection
};

//
// Messages
//

pub const MessageType = enum(u16) { // List controlled by protocol version
    command,
    depart,
    entry_request,
    map_update,
    message,
    table_update,

    pub const len = @typeInfo(@This()).@"enum".fields.len;
};

const CommandMsg = @import("CommandMessage.zig");
const MapUpdate = @import("MapUpdate.zig");
const TextMessage = @import("TextMessage.zig");
const TableUpdate = @import("TableUpdate.zig");

pub const Tile = MapUpdate.Tile;

//
//  Callbacks to the entrypoints into server or client
//

pub const VTable = struct {
    command: ?*const fn (ctx: *anyopaque, cmd: u16) Error!void = null,
    depart: ?*const fn (ctx: *anyopaque, text: []const u8) Error!void = null,
    entry: ?*const fn (ctx: *anyopaque, name: []const u8) Error!void = null,
    updateMap: ?*const fn (
        ctx: *anyopaque,
        pos: [2]i16,
        tile: MapUpdate.Tile,
    ) Error!void = null,
    updateMessage: ?*const fn (ctx: *anyopaque, text: []const u8) Error!void = null,
    updateTable: ?*const fn (
        ctx: *anyopaque,
        table: []const u8,
        entry: []const u8,
        value: []const u8,
    ) Error!void = null,
    unsupported: *const fn (ctx: *anyopaque) Error!void,
};

//
// Members
//

vt: *const VTable = undefined,
ctx: *anyopaque = undefined,
reader: *Reader = undefined,
writer: *Writer = undefined,

//
// Message Callbacks
//

fn doCommand(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *CommandMsg = @ptrCast(@alignCast(ptr));
    if (self.vt.command) |cb| {
        return cb(self.ctx, msg.c);
    } else {
        return self.vt.unsupported(self.ctx);
    }
}

fn doDepart(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *TextMessage = @ptrCast(@alignCast(ptr));
    if (self.vt.depart) |cb| {
        return cb(self.ctx, msg.text);
    } else {
        return self.vt.unsupported(self.ctx);
    }
}

fn doEntryRequest(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *TextMessage = @ptrCast(@alignCast(ptr));
    if (self.vt.entry) |cb| {
        return cb(self.ctx, msg.text);
    } else {
        return self.vt.unsupported(self.ctx);
    }
}

fn doMapUpdate(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *MapUpdate = @ptrCast(@alignCast(ptr));
    if (self.vt.updateMap) |cb| {
        return cb(self.ctx, msg.pos, msg.tile);
    } else {
        return self.vt.unsupported(self.ctx);
    }
}

fn doMessage(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *TextMessage = @ptrCast(@alignCast(ptr));
    if (self.vt.updateMessage) |cb| {
        return cb(self.ctx, msg.text);
    } else {
        return self.vt.unsupported(self.ctx);
    }
}

fn doTableUpdate(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *TableUpdate = @ptrCast(@alignCast(ptr));
    if (self.vt.updateTable) |cb| {
        return cb(self.ctx, msg.table, msg.entry, msg.value);
    } else {
        return self.vt.unsupported(self.ctx);
    }
}

//
// Create the dispatch table
//
// TODO: this is ordered according to the enum.  How to lock it down?
//

// Clients implement ReadFn
pub const ReadFn = *const fn (ctx: *anyopaque, ptr: *anyopaque) Error!void;

pub fn Read(comptime T: type, comptime FN: ReadFn) type {
    return struct {
        pub fn read(reader: *Reader, ctx: *anyopaque, allocator: Allocator) Error!void {
            // (Identifier peeled before this)

            var buf: [2]u8 = undefined;
            reader.readSliceAll(&buf) catch return error.Failed;
            const field_count = std.mem.readInt(u16, &buf, .big);
            if (field_count != @typeInfo(T).@"struct".fields.len) {
                return error.Invalid;
            }
            var msg = T.read(reader, allocator) catch return error.Failed;
            defer msg.deinit(allocator);

            try FN(ctx, msg);
        }
    };
}

pub const DispatchReadFn = *const fn (reader: *Reader, ctx: *anyopaque, allocator: Allocator) Error!void;

const fns = [MessageType.len]DispatchReadFn{
    Read(CommandMsg, doCommand).read,
    Read(TextMessage, doDepart).read,
    Read(TextMessage, doEntryRequest).read,
    Read(MapUpdate, doMapUpdate).read,
    Read(TextMessage, doMessage).read,
    Read(TableUpdate, doTableUpdate).read,
};

//
// Execute the dispatch on the table and the reader
//

pub fn run(self: *Self, allocator: Allocator) !void {
    const buffer = try allocator.alloc(u8, 325);
    defer allocator.free(buffer);
    var fba = std.heap.FixedBufferAllocator.init(buffer);
    // fba abandoned when its buffer is freed

    var int: [2]u8 = undefined;
    try self.reader.readSliceAll(&int);
    const val = std.mem.readInt(u16, &int, .big);
    if (val >= fns.len) {
        return error.InvalidType;
    }

    const cb = fns[val];
    try cb(self.reader, self, fba.allocator());
}

//
// Write wrappers
//
//  The write encampsulates the 'message type' output but the read assumes
//  it has been peeled away before this point.
//
//  Validating the message size itself is tricky without dipping into packed
//  structures or doing a manual calculation for each structure, so the
//  next best thing is to use the number of fields, which can be inspected.

fn Write(comptime T: type, comptime MT: MessageType) type {
    return struct {
        pub fn write(self: *Self, msg: T) !void {
            const field_count = @typeInfo(T).@"struct".fields.len;
            var buf: [2]u8 = undefined;
            std.mem.writeInt(u16, &buf, @intFromEnum(MT), .big);
            try self.writer.writeAll(buf[0..]);
            std.mem.writeInt(u16, &buf, field_count, .big);
            try self.writer.writeAll(buf[0..]);
            try msg.write(self.writer);
        }
    };
}

pub fn writeCommandMsg(self: *Self, cmd: u16) !void {
    const write = Write(CommandMsg, .command).write;
    try write(self, .{ .c = cmd });
}

pub fn writeDepart(self: *Self, text: []const u8) !void {
    const write = Write(TextMessage, .depart).write;
    try write(self, .{ .text = text });
}

pub fn writeEntryRequest(self: *Self, text: []const u8) !void {
    const write = Write(TextMessage, .entry_request).write;
    try write(self, .{ .text = text });
}

pub fn writeMapUpdate(self: *Self, pos: []i16, tile: Tile) !void {
    const write = Write(MapUpdate, .map_update).write;
    try write(self, .{ .pos = .{ pos[0], pos[1] }, .tile = tile });
}

pub fn writeMessage(self: *Self, text: []const u8) !void {
    const write = Write(TextMessage, .message).write;
    try write(self, .{ .text = text });
}

pub fn writeTableUpdate(self: *Self, table: []const u8, entry: []const u8, value: []const u8) !void {
    const write = Write(TableUpdate, .table_update).write;
    try write(self, .{ .table = table, .entry = entry, .value = value });
}

//
// Unit Test
//

comptime {
    _ = @import("testing.zig");
}

// EOF
