//!
//! zrogue server CLI client
//!

const std = @import("std");
const server = @import("root.zig");
const net = std.net;
const print = std.debug.print; // TODO not this
const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const Remote = server.Remote;

//
// Service wrapper
//

const Service = struct {
    remote: Remote = undefined,
    peer: net.Address = undefined,

    const Self = @This();

    // TODO should be unnecessary
    pub fn format(self: Self, w: *Writer) Writer.Error!void {
        return w.print("{f}", .{self.peer});
    }

    //
    // Message write wrappers
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

    pub fn run(self: *Self, allocator: Allocator) !void {
        try self.remote.run(allocator);
    }
};

//
// State machine callbacks
//

fn doAction(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    _ = ptr;
    print("[{f}] Unexpected Action\n", .{self});
    return error.Failed;
}

fn doCommand(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    _ = ptr;
    print("[{f}] Unexpected Command\n", .{self});
    return error.Failed;
}

fn doDepart(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    const msg: *server.Depart = @ptrCast(@alignCast(ptr));

    print("[{f}] Disconnecting: message '{s}'\n", .{ self, msg.message });
    return error.Failed; // TODO: elegance
}

fn doEntryRequest(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    _ = ptr;
    print("[{f}] Unexpected message\n", .{self});
    return error.Failed;
}

fn doMapUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    const msg: *server.MapUpdate = @ptrCast(@alignCast(ptr));
    print(
        "[{f}] : map ({},{}) : {} {} {} {}\n",
        .{
            self, msg.x, msg.y, msg.tile.entity, msg.tile.item, msg.tile.floor, msg.tile.visible,
        },
    );
}

fn doMessage(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    const msg: *server.Message = @ptrCast(@alignCast(ptr));
    print("[{f}] : '{s}'\n", .{ self, msg.message });
}

fn doTableUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    const msg: *server.TableUpdate = @ptrCast(@alignCast(ptr));
    print("[{f}] : update {s}/{s} : {s}\n", .{ self, msg.table, msg.entry, msg.value });
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
// Main
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // TODO: better

    var args = std.process.args();
    // The first (0 index) Argument is the path to the program.
    _ = args.skip();
    const port_value = args.next() orelse {
        print("expect port as command line argument\n", .{});
        return error.NoPort;
    };

    const port = try std.fmt.parseInt(u16, port_value, 10);
    const peer = try net.Address.parseIp4("127.0.0.1", port);
    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();

    print("Connecting to {f}\n", .{peer});

    const rbuf = allocator.alloc(u8, 1000) catch |err| {
        print("alloc read buffer: {}", .{err});
        return err;
    };
    errdefer allocator.free(rbuf);

    var reader = stream.reader(rbuf);
    var writer = stream.writer(&.{});

    var service = Service{
        .peer = peer,
        .remote = Remote{
            .reader = reader.interface(),
            .writer = &writer.interface,
            .sm = &rig,
        },
    };
    service.remote.ctx = &service;

    // TODO handle errors
    // TODO player name
    try service.writeEntryRequest("anonymous");

    // TODO: need to absorb messages, reply, etc
    try service.run(allocator);
    try service.run(allocator);
    try service.writeAction(.none, &.{ 0, 0 });
    try service.writeDepart("ending");

    print("Disconnected from {f}\n", .{peer});
}
