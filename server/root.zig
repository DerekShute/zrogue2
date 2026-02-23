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
//!
//!   ACTION msgpack ->
//! ]
//!
//!   DEPART msgpack ->
//!                 (or)
//!                  <- DEPART msgpack
//!
//!                  <- ERROR msgpack
//!

const std = @import("std");
const Writer = std.io.Writer;
const Reader = std.io.Reader;

pub const Remote = @import("Remote.zig");

//
// Master enumeration for messages
//

pub const MessageType = enum(u16) { // List controlled by protocol version
    depart,
    entry_request,
    message,

    const Self = @This();

    pub fn read(reader: *Reader) !Self {
        var buffer: [2]u8 = undefined;

        try reader.readSliceAll(&buffer);
        const val = std.mem.readInt(u16, &buffer, .big);

        if (val > @intFromEnum(Self.message)) {
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

pub const Depart = @import("protocol/Depart.zig");
pub const EntryRequest = @import("protocol/EntryRequest.zig");
pub const Message = @import("protocol/Message.zig");

//
// Constants
//

pub const max_player_name_length = EntryRequest.max_name_len;
pub const max_game_message_length = Message.max_message_len;

//
// Imports
//

comptime {
    _ = @import("Remote.zig");
    _ = @import("protocol/Depart.zig");
    _ = @import("protocol/EntryRequest.zig");
    _ = @import("protocol/Message.zig");
}

// EOF
