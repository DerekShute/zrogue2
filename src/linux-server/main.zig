//!
//! Linux cli-based server
//!

const std = @import("std");
const game = @import("game");
const RemoteClient = @import("RemoteClient.zig");

const Allocator = std.mem.Allocator;

const log = std.log.scoped(.server);
const net = std.Io.net;

//
// Client connection
//

fn handleClient(io: std.Io, conn: *net.Stream, allocator: Allocator) !void {
    const name = try std.fmt.allocPrint(allocator, "{f}", .{conn.socket.address});
    defer allocator.free(name);

    log.info("[{s}] Accepted connection", .{name});

    const rbuf = try allocator.alloc(u8, 1024);
    defer allocator.free(rbuf);
    var reader = conn.reader(io, rbuf);
    var writer = conn.writer(io, &.{});

    const config = RemoteClient.Config{
        .allocator = allocator,
        .reader = &reader.interface,
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

        try rc.writeDepart("Game Ending");
    }

    log.info("[{s}] End session", .{name});
}

//
// Main
//

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const addr = try net.IpAddress.parse("127.0.0.1", 0);
    var service = try addr.listen(init.io, .{ .reuse_address = true });
    defer service.deinit(init.io);

    log.info("[{}] Listening", .{service.socket.address});
    while (true) {
        var connection = try service.accept(init.io);
        defer connection.stream.close();

        try handleClient(init.io, &connection, allocator);
    }
}

// EOF
