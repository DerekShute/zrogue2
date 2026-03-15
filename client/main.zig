//!
//! zrogue server CLI client
//!

const std = @import("std");
const server = @import("server");
const net = std.net;
const print = std.debug.print; // TODO not this

const Remote = server.Remote;

//
// State machine callbacks
//
// TODO: returns error to close connection

fn doAction(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    _ = ptr;
    print("[{f}] Unexpected Action\n", .{remote});
    remote.setState(.closing);
}

fn doDepart(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    const msg: *server.Depart = @ptrCast(@alignCast(ptr));
    print("[{f}] Disconnecting: message '{s}'\n", .{ remote, msg.message });
    remote.setState(.closing);
}

fn doEntryRequest(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    _ = ptr;
    print("[{f}] Unexpected message\n", .{remote});
    remote.setState(.closing);
}

fn doMapUpdate(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    const msg: *server.MapUpdate = @ptrCast(@alignCast(ptr));
    print(
        "[{f}] : map ({},{}) : {} {} {} {}\n",
        .{
            remote, msg.x, msg.y, msg.tile.entity, msg.tile.item, msg.tile.floor, msg.tile.visible,
        },
    );
}

fn doMessage(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    const msg: *server.Message = @ptrCast(@alignCast(ptr));
    print("[{f}] : '{s}'\n", .{ remote, msg.message });
}

fn doTableUpdate(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    const msg: *server.TableUpdate = @ptrCast(@alignCast(ptr));
    print("[{f}] : update {s}/{s} : {s}\n", .{ remote, msg.table, msg.entry, msg.value });
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

    const name = try std.fmt.allocPrint(allocator, "{f}", .{peer});
    defer allocator.free(name);

    print("Connecting to {s}\n", .{name});

    const rbuf = allocator.alloc(u8, 1000) catch |err| {
        print("alloc read buffer: {}", .{err});
        return err;
    };
    errdefer allocator.free(rbuf);

    var reader = stream.reader(rbuf);
    var writer = stream.writer(&.{});

    // TODO: server struct with methods
    var remote = Remote{
        .name = name,
        .reader = reader.interface(),
        .writer = &writer.interface,
        .sm = &rig,
    };

    // TODO handle errors
    // TODO player name
    try server.writeEntryRequest(&remote, "anonymous");

    // TODO: need to absorb messages, reply, etc
    try remote.run(allocator);

    try server.writeAction(&remote, .none, &.{ 0, 0 });
    try remote.run(allocator);
    try server.writeDepart(&remote, "ending");

    print("Disconnected from {s}\n", .{name});
}
