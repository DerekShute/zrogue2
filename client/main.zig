//!
//! zrogue server CLI client
//!

const std = @import("std");
const server = @import("server");
const net = std.net;
const print = std.debug.print; // TODO not this

const Remote = server.Remote;

// TODO: boilerplate

pub fn writeAction(remote: *Remote, kind: server.Action.Kind, pos: []const i16) !void {
    var alloc_b: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try server.Action.init(fba.allocator(), kind, pos);
    // abandoned
    try server.writeAction(remote, msg.*);
}

fn writeDepart(remote: *Remote, text: []const u8) !void {
    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try server.Depart.init(fba.allocator(), text);
    // abandoned
    try server.writeDepart(remote, msg.*);
}

fn writeEntryRequest(remote: *Remote, text: []const u8) !void {
    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try server.EntryRequest.init(fba.allocator(), text);
    // abandoned
    try server.writeEntryRequest(remote, msg.*);
}

fn writeMessage(remote: *Remote, text: []const u8) !void {
    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try server.Message.init(fba.allocator(), text);
    // abandoned
    try server.writeMessage(remote, msg.*);
}

fn writeMapUpdate(remote: *Remote, pos: []const i16, tile: server.MapUpdate.DisplayTile) !void {
    var alloc_b: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try server.MapUpdate.init(fba.allocator(), pos, tile);
    // abandoned
    try server.writeMapUpdate(remote, msg.*);
}

pub fn writeTableUpdate(remote: *Remote, table: []const u8, entry: []const u8, value: []const u8) !void {
    var alloc_b: [200]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = try server.TableUpdate.init(fba.allocator(), table, entry, value);
    // abandoned
    try server.writeTableUpdate(remote, msg.*);
}

//
// State machine callbacks
//

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

// TODO: boilerplate, some kind of wrapper?
const rig = [_]Remote.DispatchFn{
    Remote.Dispatch(server.Action, doAction).dispatch,
    Remote.Dispatch(server.Depart, doDepart).dispatch,
    Remote.Dispatch(server.EntryRequest, doEntryRequest).dispatch,
    Remote.Dispatch(server.MapUpdate, doMapUpdate).dispatch,
    Remote.Dispatch(server.Message, doMessage).dispatch,
    Remote.Dispatch(server.TableUpdate, doTableUpdate).dispatch,
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
        .sm = &rig,
    };

    // TODO handle errors
    // TODO player name
    try writeEntryRequest(&remote, "anonymous");

    // TODO: need to absorb messages, reply, etc
    try remote.run(allocator);

    try writeAction(&remote, .none, &.{ 0, 0 });
    try remote.run(allocator);
    try writeDepart(&remote, "ending");

    print("Disconnected from {s}\n", .{name});
}
