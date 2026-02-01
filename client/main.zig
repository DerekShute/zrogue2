//!
//! https://cookbook.ziglang.cc/04-02-tcp-client/
//!

const std = @import("std");
const server = @import("server");
const net = std.net;
const print = std.debug.print;

pub fn main() !void {
    // TODO: better
    var args = std.process.args();
    // The first (0 index) Argument is the path to the program.
    _ = args.skip();
    const port_value = args.next() orelse {
        print("expect port as command line argument\n", .{});
        return error.NoPort;
    };
    // TODO: subroutine returns stream
    const port = try std.fmt.parseInt(u16, port_value, 10);
    const peer = try net.Address.parseIp4("127.0.0.1", port);
    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();
    print("Connecting to {f}\n", .{peer});

    var rbuf: [1024]u8 = undefined;
    var reader = stream.reader(&rbuf);
    var writer = stream.writer(&.{});

    // TODO handle
    try server.startHandshake(&writer.interface);

    // TODO handle
    _ = try server.receiveHandshakeResponse(reader.interface());

    // TODO: next step
}
