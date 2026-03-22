//!
//! Linux cli-based server
//!

const std = @import("std");
const game = @import("game");
const server = @import("root.zig");
const RemoteClient = @import("RemoteClient.zig");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const log = std.log.scoped(.server);
const net = std.net;

const Remote = server.Remote;

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

    const config = RemoteClient.Config{
        .allocator = allocator,
        .reader = reader.interface(),
        .writer = &writer.interface,
        .name = name,
    };
    var rc = try RemoteClient.init(config);
    defer rc.deinit(allocator);

    // Create a limited allocator here for catching incoming messages
    const buffer = try allocator.alloc(u8, 2000);
    defer allocator.free(buffer);
    var fb = std.heap.FixedBufferAllocator.init(buffer);

    var arena = std.heap.ArenaAllocator.init(fb.allocator());
    defer arena.deinit();

    rc.run(arena.allocator());
    if (rc.getState() == .starting) {
        rc.setState(.connected);

        var player = game.Player.init(.{
            .client = rc.client(),
            .allocator = allocator,
            .maxx = 80, // TODO annoying fantasy
            .maxy = 24,
        });

        try game.run(.{
            .player = &player,
            .allocator = allocator,
        });
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
