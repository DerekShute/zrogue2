//!
//! Game Client network connector service
//!
//! I am running out of ideas for names
//!

const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const server = @import("root.zig");
const Remote = server.Remote;

const Self = @This();

//
// Types
//

pub const VTable = struct {
    updateMap: *const fn (
        x: i16,
        y: i16,
        tile: server.MapUpdate.Tile,
    ) void,
    updateMessage: *const fn (
        text: []const u8,
    ) void,
    updateTable: *const fn (
        table: []const u8,
        entry: []const u8,
        value: []const u8,
    ) void,
};

//
// Members
//

remote: Remote = undefined,
peer: net.Address = undefined,
vt: *VTable = undefined,

//
// Message write wrappers
//
// TODO mutual exclusion?
//

fn Wrap(comptime T: type, comptime MT: server.MessageType) type {
    // It's just wrappers all the way down.  This just simplifies the
    // invocation in the write declaration
    return struct {
        pub fn write(self: *Self, msg: T) !void {
            const r_write = Remote.Write(T, @intFromEnum(MT)).write;
            try r_write(&self.remote, msg);
        }
    };
}

pub fn writeEntryRequest(self: *Self, text: []const u8) !void {
    const write = Wrap(server.EntryRequest, .entry_request).write;
    try write(self, .{ .name = text });
}

pub fn writeAction(self: *Self, kind: server.ActionMsg.Type, pos: []const i16) !void {
    const write = Wrap(server.ActionMsg, .action).write;
    try write(self, .{ .kind = kind, .x = pos[0], .y = pos[1] });
}

pub fn writeDepart(self: *Self, text: []const u8) !void {
    const write = Wrap(server.Depart, .depart).write;
    try write(self, .{ .message = text });
}

//
// State machine callbacks
//

fn doAction(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    _ = ctx;
    _ = ptr;
    return error.Failed;
}

fn doCommand(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    _ = ctx;
    _ = ptr;
    return error.Failed;
}

fn doDepart(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    _ = ctx;
    _ = ptr;
    return error.Failed; // TODO: elegance
}

fn doEntryRequest(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    _ = ctx;
    _ = ptr;
    return error.Failed;
}

//
// Valid messages
//

fn doMapUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *server.MapUpdate = @ptrCast(@alignCast(ptr));
    self.vt.updateMap(@intCast(msg.x), @intCast(msg.y), msg.tile);
}

fn doMessage(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *server.Message = @ptrCast(@alignCast(ptr));
    self.vt.updateMessage(msg.message);
}

fn doTableUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *server.TableUpdate = @ptrCast(@alignCast(ptr));
    self.vt.updateTable(msg.table, msg.entry, msg.value);
}

//
// Dispatch table for server run
//
const fns = [_]Remote.ReadFn{
    doAction,
    doCommand,
    doDepart,
    doEntryRequest,
    doMapUpdate,
    doMessage,
    doTableUpdate,
};
const rig = server.genDispatch(fns);

//
// Run wrapper
//

pub fn run(self: *Self, allocator: Allocator) !void {
    self.remote.sm = &rig;
    self.remote.ctx = self;

    // TODO player name

    try self.writeEntryRequest("anonymous");

    while (true) {
        try self.remote.run(allocator);
    }
}

// EOF
