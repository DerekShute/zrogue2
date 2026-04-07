//!
//! Connector: messages in and out
//!

const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const remote = @import("remote.zig");

const Self = @This();

//
// Messages
//

pub const MessageType = enum(u16) { // List controlled by protocol version
    action,
    command,
    depart,
    entry_request,
    map_update,
    message,
    table_update,

    pub const len = @typeInfo(@This()).@"enum".fields.len;
};

const ActionMsg = @import("ActionMsg.zig");
const CommandMsg = @import("CommandMsg.zig"); // TODO deprecate?
const Depart = @import("Depart.zig");
const EntryRequest = @import("EntryRequest.zig");
const MapUpdate = @import("MapUpdate.zig");
const Message = @import("Message.zig");
const TableUpdate = @import("TableUpdate.zig");

//
// Constants provided by the message validation etc.
//

pub const max_player_name_length = EntryRequest.max_name_len;
pub const max_game_message_length = Message.max_message_len;
pub const max_table_length = TableUpdate.max_len;

//
//  Callbacks to the entrypoints into server or client
//

pub const MapTile = MapUpdate.MapTile;
pub const Tile = MapUpdate.Tile; // four MapTile, TODO this is confusing

pub const Error = remote.Error;

pub const VTable = struct {
    command: ?*const fn (ctx: *anyopaque, cmd: Command) Error!void = null,
    depart: ?*const fn (ctx: *anyopaque, text: []const u8) Error!void = null,
    entry: ?*const fn (ctx: *anyopaque, name: []const u8) Error!void = null,
    updateMap: ?*const fn (
        ctx: *anyopaque,
        x: i16,
        y: i16,
        tile: Tile,
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

fn doAction(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    _ = ctx;
    _ = ptr;
    return error.Failed;
}

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
    const msg: *Depart = @ptrCast(@alignCast(ptr));
    if (self.vt.depart) |cb| {
        return cb(self.ctx, msg.message);
    } else {
        return self.vt.unsupported(self.ctx);
    }
}

fn doEntryRequest(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *EntryRequest = @ptrCast(@alignCast(ptr));
    if (self.vt.entry) |cb| {
        return cb(self.ctx, msg.name);
    } else {
        return self.vt.unsupported(self.ctx);
    }
}

fn doMapUpdate(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *MapUpdate = @ptrCast(@alignCast(ptr));
    if (self.vt.updateMap) |cb| {
        return cb(self.ctx, @intCast(msg.x), @intCast(msg.y), msg.tile);
    } else {
        return self.vt.unsupported(self.ctx);
    }
}

fn doMessage(ctx: *anyopaque, ptr: *anyopaque) Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *Message = @ptrCast(@alignCast(ptr));
    if (self.vt.updateMessage) |cb| {
        return cb(self.ctx, msg.message);
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

const fns = [MessageType.len]remote.DispatchReadFn{
    remote.Read(ActionMsg, doAction).read,
    remote.Read(CommandMsg, doCommand).read,
    remote.Read(Depart, doDepart).read,
    remote.Read(EntryRequest, doEntryRequest).read,
    remote.Read(MapUpdate, doMapUpdate).read,
    remote.Read(Message, doMessage).read,
    remote.Read(TableUpdate, doTableUpdate).read,
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

fn Wrap(comptime T: type, comptime MT: MessageType) type {
    // It's just wrappers all the way down.  This just simplifies the
    // invocation in the write declaration
    return struct {
        pub fn write(self: *Self, msg: T) !void {
            const r_write = remote.Write(T, @intFromEnum(MT)).write;
            try r_write(self.writer, msg);
        }
    };
}

pub fn writeAction(self: *Self, kind: ActionMsg.Type, pos: []const i16) !void {
    const write = Wrap(ActionMsg, .action).write;
    try write(self, .{ .kind = kind, .x = pos[0], .y = pos[1] });
}

pub const Command = CommandMsg.Command;

pub fn writeCommandMsg(self: *Self, cmd: Command) !void {
    const write = Wrap(CommandMsg, .command).write;
    try write(self, .{ .c = cmd });
}

pub fn writeDepart(self: *Self, text: []const u8) !void {
    const write = Wrap(Depart, .depart).write;
    try write(self, .{ .message = text });
}

pub fn writeEntryRequest(self: *Self, text: []const u8) !void {
    const write = Wrap(EntryRequest, .entry_request).write;
    try write(self, .{ .name = text });
}

pub fn writeMapUpdate(self: *Self, pos: []const i16, tile: Tile) !void {
    const write = Wrap(MapUpdate, .map_update).write;
    try write(self, .{ .x = pos[0], .y = pos[1], .tile = tile });
}

pub fn writeMessage(self: *Self, text: []const u8) !void {
    const write = Wrap(Message, .message).write;
    try write(self, .{ .message = text });
}

pub fn writeTableUpdate(self: *Self, table: []const u8, entry: []const u8, value: []const u8) !void {
    const write = Wrap(TableUpdate, .table_update).write;
    try write(self, .{ .table = table, .entry = entry, .value = value });
}

//
// Imports
//

comptime {
    _ = @import("testing.zig");
    _ = @import("ActionMsg.zig");
    _ = @import("CommandMsg.zig");
    _ = @import("Depart.zig");
    _ = @import("EntryRequest.zig");
    _ = @import("MapUpdate.zig");
    _ = @import("Message.zig");
    _ = @import("TableUpdate.zig");
}

// EOF
