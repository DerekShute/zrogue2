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
// TODO still a lot of boilerplate here, and need for an allocator is ugh

fn Wrap(comptime T: type, comptime MT: MessageType) type {
    // TODO: might be able to return function pointer
    return struct {
        pub const write = Remote.Write(T, @intFromEnum(MT)).write;
    };
}

pub fn writeAction(remote: *Remote, kind: Action.Kind, pos: []const i16) !void {
    const write = Wrap(Action, .action).write;
    var alloc_b: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try Action.init(fba.allocator(), kind, pos);
    // abandoned
    try write(remote, msg.*);
}

pub fn writeDepart(remote: *Remote, text: []const u8) !void {
    const write = Wrap(Depart, .depart).write;
    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try Depart.init(fba.allocator(), text);
    // abandoned
    try write(remote, msg.*);
}

pub fn writeEntryRequest(remote: *Remote, text: []const u8) !void {
    const write = Wrap(EntryRequest, .entry_request).write;
    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try EntryRequest.init(fba.allocator(), text);
    // abandoned
    try write(remote, msg.*);
}

pub fn writeMapUpdate(remote: *Remote, pos: []const i16, tile: MapUpdate.DisplayTile) !void {
    const write = Wrap(MapUpdate, .map_update).write;
    var alloc_b: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try MapUpdate.init(fba.allocator(), pos, tile);
    // abandoned
    try write(remote, msg.*);
}

pub fn writeMessage(remote: *Remote, text: []const u8) !void {
    const write = Wrap(Message, .message).write;
    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try Message.init(fba.allocator(), text);
    // abandoned
    try write(remote, msg.*);
}

pub fn writeTableUpdate(remote: *Remote, table: []const u8, entry: []const u8, value: []const u8) !void {
    const write = Wrap(TableUpdate, .table_update).write;
    var alloc_b: [200]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try TableUpdate.init(fba.allocator(), table, entry, value);
    // abandoned
    try write(remote, msg.*);
}

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
