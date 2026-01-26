//!
//! https://cookbook.ziglang.cc/04-01-tcp-server/
//! Test with
//! echo "hello zig" | nc localhost <port>

const std = @import("std");
const server = @import("root.zig");
const net = std.net;
const print = std.debug.print; // TODO logger

//
// Service routines
//

fn handleClient(stream: *net.Stream, allocator: std.mem.Allocator) !void {
    var rbuf: [1024]u8 = undefined;
    var reader = stream.reader(&rbuf);
    var writer = stream.writer(&.{});

    // TODO logging error
    const req = server.receiveHandshakeReq(reader.interface(), allocator) catch return;

    // TODO catch
    try server.sendHandshakeResponse(
        &writer.interface,
        allocator,
        req.nonce,
        .awaiting_entry,
    );

    // TODO: next step
}

//
// Main
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const loopback = try net.Ip4Address.parse("127.0.0.1", 0);
    const localhost = net.Address{ .in = loopback };
    var service = try localhost.listen(.{
        .reuse_address = true,
    });
    defer service.deinit();

    while (true) {
        const addr = service.listen_address;
        print("Listening on {}\n", .{addr.getPort()});
        var client = try service.accept();
        defer client.stream.close();
        print("Accepted connection from {f}\n", .{client.address});
        try handleClient(&client.stream, allocator);
    }
}

// EOF
