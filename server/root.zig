//!
//! Server library stashed here for convenience.  Import on client side
//!
//! Transaction:
//!
//!    ENTRY msgpack ->
//! [
//!                  <- MAP_UPDATE msgpack
//!                  <- MESSAGE msgpack
//!                  <- STAT_UPDATE msgpack
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

pub const Remote = @import("Remote.zig");

//
// Master enumeration for messages
//

pub const MessageType = enum(u16) { // List controlled by protocol version
    action,
    depart,
    entry_request,
    map_update,
    message,
    table_update,

    const Self = @This();
    pub const count = @typeInfo(Self).@"enum".fields.len;

    pub fn read(reader: *Reader) !Self {
        var buffer: [2]u8 = undefined;

        try reader.readSliceAll(&buffer);
        const val = std.mem.readInt(u16, &buffer, .big);

        if (val > Self.count) {
            return error.BadMessage;
        }
        return @enumFromInt(val);
    }

    pub fn write(mt: Self, writer: *Writer) !void {
        var buffer: [2]u8 = undefined;

        // TODO Could panic on > message

        std.mem.writeInt(u16, &buffer, @intFromEnum(mt), .big);
        try writer.writeAll(buffer[0..]);
        try writer.flush();
    }
};

//
// Message listing
//

pub const Action = @import("protocol/Action.zig");
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
// Imports
//

comptime {
    _ = @import("Remote.zig");
    _ = @import("protocol/Action.zig");
    _ = @import("protocol/Depart.zig");
    _ = @import("protocol/EntryRequest.zig");
    _ = @import("protocol/MapUpdate.zig");
    _ = @import("protocol/Message.zig");
    _ = @import("protocol/TableUpdate.zig");
}

// EOF
