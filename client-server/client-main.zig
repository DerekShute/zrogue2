//!
//! zrogue server CLI client
//!

const std = @import("std");
const server = @import("root.zig"); // TODO
const net = std.net;
const print = std.debug.print; // TODO not this
const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const Remote = server.Remote;

// TODO: expanding to its own thing
const Service = struct {
    remote: Remote = undefined,
    peer: net.Address = undefined,

    // TODO should be unnecessary
    pub fn format(self: @This(), w: *Writer) Writer.Error!void {
        return w.print("{f}", .{self.peer});
    }

    pub fn writeEntryRequest(self: *@This(), text: []const u8) !void {
        try server.writeEntryRequest(&self.remote, text);
    }

    pub fn writeAction(self: *@This(), kind: server.Action.Kind, pos: []const i16) !void {
        try server.writeAction(&self.remote, kind, pos);
    }

    pub fn writeDepart(self: *@This(), text: []const u8) !void {
        try server.writeDepart(&self.remote, text);
    }

    pub fn run(self: *@This(), allocator: Allocator) !void {
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

    try service.writeAction(.none, &.{ 0, 0 });
    try service.run(allocator);
    try service.run(allocator);
    try service.writeDepart("ending");

    print("Disconnected from {f}\n", .{peer});
}
