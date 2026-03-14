//!
//! Linux cli-based server
//!

const std = @import("std");
const server = @import("root.zig");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const log = std.log.scoped(.server);
const net = std.net;

const Remote = server.Remote;

//
// State machine callbacks
//

fn doAction(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    const msg: *server.Action = @ptrCast(@alignCast(ptr));

    if (remote.getState() != .connected) {
        log.info(
            "[{f}] Action in wrong state '{}'",
            .{ remote, remote.getState() },
        );
        remote.setState(.closing);
        return;
    }
    log.info("[{f}] Action: {} {},{}", .{ remote, msg.kind, msg.x, msg.y });
}

fn doDepart(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    const msg: *server.Depart = @ptrCast(@alignCast(ptr));

    log.info("[{f}] Disconnecting: message '{s}'", .{ remote, msg.message });
    remote.setState(.closing);
}

fn doEntryRequest(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    const msg: *server.EntryRequest = @ptrCast(@alignCast(ptr));

    if (remote.getState() != .init) {
        log.info(
            "[{f}] EntryRequest in wrong state '{}'",
            .{ remote, remote.getState() },
        );
        remote.setState(.closing);
        return;
    }

    log.info("[{f}] Connected: player '{s}'", .{ remote, msg.name });
    remote.setState(.connected);

    server.writeMessage(remote, "Welcome to the Dungeon of Doom!") catch {
        log.info("[{f}] Send error, disconnecting", .{remote});
        remote.setState(.closing);
        return;
    };

    const tile = server.MapUpdate.DisplayTile{
        .entity = .unknown,
        .item = .gold,
        .floor = .wall,
        .visible = true,
    };

    server.writeMapUpdate(remote, &.{ 0, 1 }, tile) catch {
        log.info("[{f}] Send error map-update, disconnecting", .{remote});
        remote.setState(.closing);
        return;
    };

    server.writeTableUpdate(remote, "stats", "purse", "0") catch {
        log.info("[{f}] Send error table-update, disconnecting", .{remote});
        remote.setState(.closing);
        return;
    };
}

fn doMapUpdate(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    _ = ptr; // Don't care, possibly pathological

    log.info("[{f}] Unexpected map update", .{remote});
    remote.setState(.closing);
}

fn doMessage(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    _ = ptr; // Don't care, possibly pathological

    log.info("[{f}] Unexpected message", .{remote});
    remote.setState(.closing);
}

fn doTableUpdate(remote: *Remote, ptr: *anyopaque) Remote.Error!void {
    _ = ptr;
    log.info("[{f}] Unexpected table update", .{remote});
    remote.setState(.closing);
}

const rig = [_]Remote.DispatchFn{
    Remote.Dispatch(server.Action, doAction).dispatch,
    Remote.Dispatch(server.Depart, doDepart).dispatch,
    Remote.Dispatch(server.EntryRequest, doEntryRequest).dispatch,
    Remote.Dispatch(server.MapUpdate, doMapUpdate).dispatch,
    Remote.Dispatch(server.Message, doMessage).dispatch,
    Remote.Dispatch(server.TableUpdate, doTableUpdate).dispatch,
};

//
// Client connection
//

fn handleClient(conn: *net.Server.Connection, allocator: Allocator) !void {
    const name = try std.fmt.allocPrint(allocator, "{f}", .{conn.address});
    defer allocator.free(name);

    log.info("[{s}] Accepted connection", .{name});

    const rbuf = try allocator.alloc(u8, 1024);
    defer allocator.free(rbuf);
    var reader = conn.stream.reader(rbuf);
    var writer = conn.stream.writer(&.{});

    var remote = Remote{
        .name = name,
        .reader = reader.interface(),
        .writer = &writer.interface,
        .sm = &rig,
    };

    //
    // Create a limited allocator here for catching incoming messages
    //
    const buffer = try allocator.alloc(u8, 2000);
    defer allocator.free(buffer);
    var fb = std.heap.FixedBufferAllocator.init(buffer);

    while (remote.getState() != .closing) {
        var arena = std.heap.ArenaAllocator.init(fb.allocator());
        defer arena.deinit();
        remote.run(arena.allocator()) catch |err| {
            log.info("[{s}] error {}", .{ name, err });
            remote.setState(.closing);
        };
    }

    log.info("[{s}] End session", .{name});
}

//
// Main
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const loopback = try net.Ip4Address.parse("127.0.0.1", 0);
    const localhost = net.Address{ .in = loopback };
    var service = try localhost.listen(.{
        .reuse_address = true,
    });
    defer service.deinit();

    log.info("[{}] Listening", .{service.listen_address.getPort()});
    while (true) {
        var connection = try service.accept();
        defer connection.stream.close();

        try handleClient(&connection, gpa.allocator());
    }
}

// EOF
