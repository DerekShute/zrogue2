const std = @import("std");
const server = @import("root.zig");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;
const MessageType = server.MessageType;

const log = std.log.scoped(.player);

const Self = @This();

//
// Types
//

const CallbackFn = *const fn (conn: *Self, ctx: *anyopaque) void;

pub const MsgAction = struct {
    cb: CallbackFn,
};

// const rig = &[_]MsgAction{
//    .{ .cb = doThing },
//    ...,
// };

pub const State = enum {
    init,
    connected,
    closing,
};

//
// Members
//

// TODO: convert to formatted string so this code does not care
address: std.net.Address = undefined,
reader: *Reader = undefined,
writer: *Writer = undefined,
sm: []const MsgAction = undefined,
state: State = .init,
// TODO: player name

//
// Service
//

fn reportError(self: *Self, err: server.Error) void {
    switch (err) {
        // TODO protocol/state error
        error.ConnectionDropped => {
            log.info("[{f}] Unexpected disconnection", .{self});
        },
        error.BadMessage => {
            log.info("[{f}] Invalid message", .{self});
        },
        else => {
            log.info("[{f}] Unexpected error {}", .{ self, err });
        },
    }
}

//
// Callback hooks
//
// TODO: this is all boilerplate...how to consolidate?

fn receiveDepart(self: *Self, allocator: Allocator) !void {
    const msg = try server.readDepart(allocator, self.reader);
    defer msg.deinit(allocator);

    const act = self.sm[@intFromEnum(MessageType.depart)];
    act.cb(self, msg);
}

fn receiveEntryRequest(self: *Self, allocator: Allocator) !void {
    const msg = try server.readEntryRequest(allocator, self.reader);
    defer msg.deinit(allocator);

    const act = self.sm[@intFromEnum(MessageType.entry_request)];
    act.cb(self, msg);
}

fn receiveMessage(self: *Self, allocator: Allocator) !void {
    const msg = try server.readMessage(allocator, self.reader);
    defer msg.deinit(allocator);

    const act = self.sm[@intFromEnum(MessageType.message)];
    act.cb(self, msg);
}

//
// Interface
//

pub fn setState(self: *Self, state: State) void {
    self.state = state;
}

pub fn getState(self: *Self) State {
    return self.state;
}

pub fn readNextAndAct(self: *Self, allocator: Allocator) void {
    const mt = server.MessageType.read(self.reader) catch {
        self.setState(.closing);
        return;
        // self.reportError(err);
        // EndOfStream / ReadFailed
    };

    const retval = switch (mt) {
        .depart => self.receiveDepart(allocator),
        .entry_request => self.receiveEntryRequest(allocator),
        .message => self.receiveMessage(allocator),
    };

    return retval catch |err| {
        self.reportError(err);
        self.setState(.closing);
    };
}

pub fn writeDepart(self: *Self, msg: []const u8) !void {
    try server.writeDepart(self.writer, msg); // TODO catch
}

pub fn writeMessage(self: *Self, msg: []const u8) !void {
    server.writeMessage(self.writer, msg) catch |err| switch (err) {
        error.ConnectionDropped => return error.ConnectionDropped,
        else => {
            log.info("[{f}] Message returned {}", .{ self, err });
            return error.UnexpectedError;
        },
    };
}

//
// Formatter
//

pub fn format(self: Self, w: *Writer) Writer.Error!void {
    return w.print("{f}", .{self.address}); // TODO player name
}

// EOF
