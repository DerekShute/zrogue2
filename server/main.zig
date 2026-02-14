//!
//! https://cookbook.ziglang.cc/04-01-tcp-server/
//! Test with
//! echo "hello zig" | nc localhost <port>

const std = @import("std");
const server = @import("root.zig");

const log = std.log.scoped(.server);
const net = std.net;

//
// Service routines
//

// TODO: accepts allocator for game creation etc

fn handleClient(conn: *net.Server.Connection) void {
    var buffer: [1000]u8 = undefined; // TODO: arena allocator?
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    var rbuf: [1024]u8 = undefined;
    var reader = conn.stream.reader(&rbuf);
    //var writer = conn.stream.writer(&.{});

    log.info("[{f}] Accepted connection", .{conn.address});

    // TODO: reads header that identifies type
    // TODO: loop

    // TODO: local routine to capture this
    const req = server.readEntryRequest(
        fba.allocator(),
        reader.interface(),
    ) catch |err| {
        switch (err) {
            server.Error.ConnectionDropped => {
                log.info("Unexpected disconnection from {f}", .{conn.address});
            },
            server.Error.BadMessage => {
                log.info("Invalid message from {f}, expecting EntryRequest", .{conn.address});
            },
            else => {
                log.info("Unexpected error {} from {f}", .{ err, conn.address });
            },
        }
        return; // Disconnects
    };
    defer req.deinit(fba.allocator());

    log.info("[{f} EntryRequest] player '{s}'", .{ conn.address, req.name });

    // TODO: next step

    log.info("[{f} '{s}'] End session", .{ conn.address, req.name });
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

    log.info("Listening on {}", .{service.listen_address.getPort()});
    while (true) {
        var connection = try service.accept();
        defer connection.stream.close();

        handleClient(&connection);
    }
}

// EOF
