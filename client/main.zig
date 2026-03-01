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

fn doAction(remote: *Remote, ptr: *anyopaque) void {
    _ = ptr;
    print("[{f}] Unexpected Action\n", .{remote});
    remote.setState(.closing);
}

fn doDepart(remote: *Remote, ptr: *anyopaque) void {
    const msg: *server.Depart = @ptrCast(@alignCast(ptr));
    print("[{f}] Disconnecting: message '{s}'\n", .{ remote, msg.message });
    remote.setState(.closing);
}

fn doEntryRequest(remote: *Remote, ptr: *anyopaque) void {
    _ = ptr;
    print("[{f}] Unexpected message\n", .{remote});
    remote.setState(.closing);
}

fn doMessage(remote: *Remote, ptr: *anyopaque) void {
    const msg: *server.Message = @ptrCast(@alignCast(ptr));
    print("[{f}] : '{s}'\n", .{ remote, msg.message });
}

fn doTableUpdate(remote: *Remote, ptr: *anyopaque) void {
    const msg: *server.TableUpdate = @ptrCast(@alignCast(ptr));
    print("[{f}] : update {s}/{s} : {s}\n", .{ remote, msg.table, msg.entry, msg.value });
}

const rig = [_]Remote.Dispatch{
    .{ .cb = doAction },
    .{ .cb = doDepart },
    .{ .cb = doEntryRequest },
    .{ .cb = doMessage },
    .{ .cb = doTableUpdate },
};

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

    var remote = Remote{
        .name = name,
        .reader = reader.interface(),
        .writer = &writer.interface,
        .sm = rig,
    };

    // TODO handle errors
    // TODO player name
    try remote.writeEntryRequest("anonymous");

    // TODO: need to absorb messages, reply, etc
    remote.run(allocator);

    try remote.writeAction(.none, &.{ 0, 0 });
    remote.run(allocator);
    try remote.writeDepart("ending");

    print("Disconnected from {s}\n", .{name});
}
