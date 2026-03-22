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
//!   COMMAND msgpack ->
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
    command,
    depart,
    entry_request,
    map_update,
    message,
    table_update,

    pub const len = @typeInfo(@This()).@"enum".fields.len;
};

pub const ActionMsg = @import("protocol/ActionMsg.zig"); // TODO deprecate?
pub const CommandMsg = @import("protocol/CommandMsg.zig");
pub const Depart = @import("protocol/Depart.zig");
pub const EntryRequest = @import("protocol/EntryRequest.zig");
pub const MapUpdate = @import("protocol/MapUpdate.zig");
pub const Message = @import("protocol/Message.zig");
pub const TableUpdate = @import("protocol/TableUpdate.zig");

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
        Dispatch(ActionMsg, getDispatch(fns, .action)).dispatch,
        Dispatch(CommandMsg, getDispatch(fns, .command)).dispatch,
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
    _ = @import("protocol/ActionMsg.zig");
    _ = @import("protocol/CommandMsg.zig");
    _ = @import("protocol/Depart.zig");
    _ = @import("protocol/EntryRequest.zig");
    _ = @import("protocol/MapUpdate.zig");
    _ = @import("protocol/Message.zig");
    _ = @import("protocol/TableUpdate.zig");
}

// EOF
