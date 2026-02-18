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

const PlayerConnection = @import("PlayerConnection.zig");

//
// State machine
//

// TODO: accepts allocator for game creation etc

fn handleClient(conn: *net.Server.Connection) void {
    var buffer: [1000]u8 = undefined; // TODO: or 1000 bytes from incoming
    var rbuf: [1024]u8 = undefined; // TODO allocate
    var reader = conn.stream.reader(&rbuf);
    var writer = conn.stream.writer(&.{});

    log.info("[{f}] Accepted connection", .{conn.address});

    var pc = PlayerConnection{
        .address = conn.address,
        .reader = reader.interface(),
        .writer = &writer.interface,
    };

    var cont: bool = true;
    while (cont) {
        // TODO: arena
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        cont = pc.readNextAndAct(fba.allocator());
    }

    log.info("[{f}] End session", .{conn.address});
}

//
// Main
//

pub fn main() !void {
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

        handleClient(&connection);
    }
}

// EOF
