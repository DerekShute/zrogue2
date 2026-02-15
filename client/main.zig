//!
//! zrogue server CLI client
//!

const std = @import("std");
const server = @import("server");
const net = std.net;
const print = std.debug.print; // TODO not this

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

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

    // TODO handle errors
    // TODO player name
    try server.writeEntryRequest(&writer.interface, "anonymous");

    // TODO: next step

    // TODO handle errors
    var depart = try server.readDepart(allocator, reader.interface());
    defer depart.deinit(allocator);

    print("Disconnected from {f}, message '{s}'\n", .{ peer, depart.message });
}
