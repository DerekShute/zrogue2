const std = @import("std");
const server = @import("root.zig");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const log = std.log.scoped(.player);

const Self = @This();

//
// Members
//

// TODO: convert to formatted string so this code does not care
address: std.net.Address = undefined,
reader: *Reader = undefined,
writer: *Writer = undefined,
// TODO: player name
// TODO connection state

//
// Service
//

fn writeDepart(self: *Self, msg: []const u8) !void {
    try server.writeDepart(self.writer, msg); // TODO catch
}

fn writeMessage(self: *Self, msg: []const u8) !void {
    server.writeMessage(self.writer, msg) catch |err| {
        log.info("[{f}] Message returned {}", .{ self.address, err });
        return error.UnexpectedError;
    };
}

fn reportError(self: *Self, err: server.Error) void {
    switch (err) {
        // TODO protocol/state error
        error.ConnectionDropped => {
            log.info("[{f}] Unexpected disconnection", .{self.address});
        },
        error.BadMessage => {
            log.info("[{f}] Invalid message", .{self.address});
        },
        else => {
            log.info("[{f}] Unexpected error {}", .{ self.address, err });
        },
    }
}

//
// Callbacks
//

fn receiveDepart(self: *Self, allocator: Allocator) !bool {
    _ = allocator;
    log.info("[{f}] disconnecting", .{self.address});
    return false;
}

fn recieveEntryRequest(self: *Self, allocator: Allocator) !bool {
    const req = try server.readEntryRequest(allocator, self.reader);
    defer req.deinit(allocator);

    log.info("[{f}] Connected - player '{s}'", .{ self.address, req.name });

    try self.writeMessage("Welcome to the Dungeon of Doom");

    return true;
}

//
// Interface
//

pub fn readNextAndAct(self: *Self, allocator: Allocator) bool {
    const mt = server.MessageType.read(self.reader) catch {
        // self.reportError(err);
        // EndOfStream / ReadFailed
        return false;
    };

    // TODO: maps per state as provided

    const retval = switch (mt) {
        .depart => self.receiveDepart(allocator),
        .entry_request => self.recieveEntryRequest(allocator),
        .message => error.ProtocolError,
    };

    return retval catch |err| {
        self.reportError(err);
        return false;
    };
}

// TODO: pub fn format(self: Self, args: anytype) Writer.Error!void

// EOF
