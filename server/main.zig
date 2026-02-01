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

fn handleClient(conn: *net.Server.Connection) !void {
    var rbuf: [1024]u8 = undefined;
    var reader = conn.stream.reader(&rbuf);
    var writer = conn.stream.writer(&.{});

    log.info("Accepted connection from {f}", .{conn.address});

    const req = server.receiveHandshakeReq(reader.interface()) catch |err| {
        if (err == server.Error.ConnectionDropped) {
            log.info("Disconnected from {f}", .{conn.address});
        } else {
            log.info("Unexpected error {} from {f}", .{ err, conn.address });
        }
        return;
    };

    // TODO: not sure about error results here
    try server.sendHandshakeResponse(
        &writer.interface,
        req.nonce,
        .awaiting_entry,
    );

    // TODO: next step

    log.info("End session of {f}", .{conn.address});
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

        try handleClient(&connection);
    }
}

// EOF
