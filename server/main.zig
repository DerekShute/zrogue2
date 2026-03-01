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

const Remote = @import("Remote.zig");

//
// State machine callbacks
//

fn doDepart(remote: *Remote, ptr: *anyopaque) void {
    const msg: *server.Depart = @ptrCast(@alignCast(ptr));

    log.info("[{f}] Disconnecting: message '{s}'", .{ remote, msg.message });
    remote.setState(.closing);
}

fn doEntryRequest(remote: *Remote, ptr: *anyopaque) void {
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

    remote.writeMessage("Welcome to the Dungeon of Doom!") catch {
        log.info("[{f}] Send error, disconnecting", .{remote});
        remote.setState(.closing);
        return;
    };

    remote.writeTableUpdate("stats", "purse", "0") catch {
        log.info("[{f}] Send error table-update, disconnecting", .{remote});
        remote.setState(.closing);
        return;
    };
}

fn doMessage(remote: *Remote, ptr: *anyopaque) void {
    _ = ptr; // Don't care, possibly pathological

    log.info("[{f}] Unexpected message", .{remote});
    remote.setState(.closing);
}

fn doTableUpdate(remote: *Remote, ptr: *anyopaque) void {
    _ = ptr;
    log.info("[{f}] Unexpected table update", .{remote});
    remote.setState(.closing);
}

const rig = [_]Remote.Dispatch{
    .{ .cb = doDepart },
    .{ .cb = doEntryRequest },
    .{ .cb = doMessage },
    .{ .cb = doTableUpdate },
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
        .sm = rig,
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
        remote.run(arena.allocator());
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
