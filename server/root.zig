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
    return struct {
        pub const write = Remote.Write(T, @intFromEnum(MT)).write;
    };
}

pub const writeAction = Wrap(Action, .action).write;
pub const writeDepart = Wrap(Depart, .depart).write;
pub const writeEntryRequest = Wrap(EntryRequest, .entry_request).write;
pub const writeMapUpdate = Wrap(MapUpdate, .map_update).write;
pub const writeMessage = Wrap(Message, .message).write;
pub const writeTableUpdate = Wrap(TableUpdate, .table_update).write;

//
// Constants
//

pub const max_player_name_length = EntryRequest.max_name_len;
pub const max_game_message_length = Message.max_message_len;
pub const max_table_length = TableUpdate.max_len;

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
