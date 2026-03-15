//!
//! Server library stashed here for convenience.  Import on client side
//!
//! Transaction:
//!
//!    ENTRY msgpack ->
//! [
//!                  <- MAP_UPDATE msgpack
//!                  <- MESSAGE msgpack
//!                  <- TABLE_UPDATE msgpack
//!
//!   ACTION msgpack ->
//! ]
//!
//!   DEPART msgpack ->
//!                 (or)
//!                  <- DEPART msgpack
//!

const std = @import("std");
const Writer = std.io.Writer;
const Reader = std.io.Reader;

pub const Remote = @import("roguelib").Remote;

//
// Messages
//

pub const MessageType = enum(u16) { // List controlled by protocol version
    action,
    depart,
    entry_request,
    map_update,
    message,
    table_update,

    pub const len = @typeInfo(@This()).@"enum".fields.len;
};

pub const Action = @import("protocol/Action.zig");
pub const Depart = @import("protocol/Depart.zig");
pub const EntryRequest = @import("protocol/EntryRequest.zig");
pub const MapUpdate = @import("protocol/MapUpdate.zig");
pub const Message = @import("protocol/Message.zig");
pub const TableUpdate = @import("protocol/TableUpdate.zig");

//
// Write methods
//

fn Wrap(comptime T: type, comptime MT: MessageType) type {
    // You can return the function body as '.write' here but that makes the
    // return type very complicated.
    return struct {
        // It's just wrappers all the way down
        pub const write = Remote.Write(T, @intFromEnum(MT)).write;
    };
}

pub fn writeAction(remote: *Remote, kind: Action.Kind, pos: []const i16) !void {
    const write = Wrap(Action, .action).write;
    try write(remote, .{ .kind = kind, .x = pos[0], .y = pos[1] });
}

pub fn writeDepart(remote: *Remote, text: []const u8) !void {
    const write = Wrap(Depart, .depart).write;
    try write(remote, .{ .message = text });
}

pub fn writeEntryRequest(remote: *Remote, text: []const u8) !void {
    const write = Wrap(EntryRequest, .entry_request).write;
    try write(remote, .{ .name = text });
}

pub fn writeMapUpdate(remote: *Remote, pos: []const i16, tile: MapUpdate.DisplayTile) !void {
    const write = Wrap(MapUpdate, .map_update).write;
    try write(remote, .{ .x = pos[0], .y = pos[1], .tile = tile });
}

pub fn writeMessage(remote: *Remote, text: []const u8) !void {
    const write = Wrap(Message, .message).write;
    try write(remote, .{ .message = text });
}

pub fn writeTableUpdate(remote: *Remote, table: []const u8, entry: []const u8, value: []const u8) !void {
    const write = Wrap(TableUpdate, .table_update).write;
    try write(remote, .{ .table = table, .entry = entry, .value = value });
}

//
// Constants
//

pub const max_player_name_length = EntryRequest.max_name_len;
pub const max_game_message_length = Message.max_message_len;
pub const max_table_length = TableUpdate.max_len;

//
// Dispatch Table
//

fn getDispatch(fns: [MessageType.len]Remote.ReadFn, mt: MessageType) Remote.ReadFn {
    // Syntactic sugar
    return fns[@intFromEnum(mt)];
}

pub fn genDispatch(fns: [MessageType.len]Remote.ReadFn) [MessageType.len]Remote.DispatchFn {
    // This guarantees that all clients have entries for each message type
    const Dispatch = Remote.Dispatch;
    return .{
        Dispatch(Action, getDispatch(fns, .action)).dispatch,
        Dispatch(Depart, getDispatch(fns, .depart)).dispatch,
        Dispatch(EntryRequest, getDispatch(fns, .entry_request)).dispatch,
        Dispatch(MapUpdate, getDispatch(fns, .map_update)).dispatch,
        Dispatch(Message, getDispatch(fns, .message)).dispatch,
        Dispatch(TableUpdate, getDispatch(fns, .table_update)).dispatch,
    };
}

//
// Imports
//

comptime {
    _ = @import("protocol/Action.zig");
    _ = @import("protocol/Depart.zig");
    _ = @import("protocol/EntryRequest.zig");
    _ = @import("protocol/MapUpdate.zig");
    _ = @import("protocol/Message.zig");
    _ = @import("protocol/TableUpdate.zig");
}

// EOF
