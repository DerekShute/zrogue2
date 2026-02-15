//!
//! Linux cli-based server
//!

const std = @import("std");
const server = @import("root.zig");

const log = std.log.scoped(.server);
const net = std.net;

//
// Service routines
//

fn readEntry(
    allocator: std.mem.Allocator,
    reader: *std.io.Reader,
    address: net.Address,
) ?*server.EntryRequest {
    // TODO: local routine to capture this
    const req = server.readEntryRequest(allocator, reader) catch |err| {
        switch (err) {
            server.Error.ConnectionDropped => {
                log.info("Unexpected disconnection from {f}", .{address});
            },
            server.Error.BadMessage => {
                log.info("Invalid message from {f}, expecting EntryRequest", .{address});
            },
            else => {
                log.info("Unexpected error {} from {f}", .{ err, address });
            },
        }
        return null;
    };

    return req;
}

fn writeDepart(writer: *std.io.Writer, msg: []const u8) !void {
    try server.writeDepart(writer, msg); // TODO catch
}

// TODO: accepts allocator for game creation etc
fn handleClient(conn: *net.Server.Connection) void {
    var buffer: [1000]u8 = undefined; // TODO: or 1000 bytes from incoming
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // TODO: arena allocator underneath this, and deinit() for safety?

    var rbuf: [1024]u8 = undefined; // TODO allocate
    var reader = conn.stream.reader(&rbuf);
    var writer = conn.stream.writer(&.{});

    log.info("[{f}] Accepted connection", .{conn.address});

    // TODO: reads header that identifies type
    // TODO: loop
    if (readEntry(fba.allocator(), reader.interface(), conn.address)) |req| {
        defer req.deinit(fba.allocator());

        log.info("[{f} EntryRequest] player '{s}'", .{ conn.address, req.name });
        writeDepart(&writer.interface, "you are done") catch |err| {
            log.info("[{f} '{s}'] Depart returned {}", .{ conn.address, req.name, err });
            return;
        };
    }

    // TODO: next step

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

    log.info("Listening on {}", .{service.listen_address.getPort()});
    while (true) {
        var connection = try service.accept();
        defer connection.stream.close();

        handleClient(&connection);
    }
}

// EOF
