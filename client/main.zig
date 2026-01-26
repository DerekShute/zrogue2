//!
//! https://cookbook.ziglang.cc/04-02-tcp-client/
//!

const std = @import("std");
const handshake = @import("server").handshake;

const net = std.net;
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args = std.process.args();
    // The first (0 index) Argument is the path to the program.
    _ = args.skip();
    const port_value = args.next() orelse {
        print("expect port as command line argument\n", .{});
        return error.NoPort;
    };
    const port = try std.fmt.parseInt(u16, port_value, 10);
    const peer = try net.Address.parseIp4("127.0.0.1", port);
    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();
    print("Connecting to {f}\n", .{peer});

    var rbuf: [1024]u8 = undefined;
    var s_reader = stream.reader(&rbuf);
    const reader = s_reader.interface();
    var writer = stream.writer(&.{});

    try handshake.sendReq(&writer.interface, allocator);
    _ = try handshake.readResp(reader, allocator);
}
