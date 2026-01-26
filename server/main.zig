//!
//! https://cookbook.ziglang.cc/04-01-tcp-server/
//! Test with
//! echo "hello zig" | nc localhost <port>

const std = @import("std");
const handshake = @import("root.zig").handshake;
const net = std.net;
const print = std.debug.print; // TODO logger

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const loopback = try net.Ip4Address.parse("127.0.0.1", 0);
    const localhost = net.Address{ .in = loopback };
    var server = try localhost.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    while (true) {
        const addr = server.listen_address;
        print("Listening on {}\n", .{addr.getPort()});
        var client = try server.accept();
        defer client.stream.close();
        print("Accepted connection from {f}\n", .{client.address});
        try handleClient(&client.stream, allocator);
    }
}

fn handleClient(stream: *net.Stream, allocator: std.mem.Allocator) !void {
    var rbuf: [1024]u8 = undefined;
    var s_reader = stream.reader(&rbuf);
    const reader = s_reader.interface();
    var writer = stream.writer(&.{});

    const req = handshake.readReq(reader, allocator) catch |err| switch (err) {
        error.EndOfStream => {
            std.debug.print("EndOfStream\n", .{});
            return;
        },
        error.UnexpectedEndOfInput => {
            std.debug.print("UnexpectedEndOfInput\n", .{});
            return;
        },
        else => return err,
    };
    try handshake.sendResp(&writer.interface, allocator, req, .awaiting_entry);
}

// EOF
