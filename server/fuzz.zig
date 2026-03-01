//!
//! zrogue client-server fuzz testing
//!

const std = @import("std");
const server = @import("root.zig");
const log = std.log;
const net = std.net;

const Remote = server.Remote;

//
// Distill error to this because no inferred error sets allowed
//

const Error = error{
    AnyError,
};

fn writeDepart(remote: *Remote, name: []const u8) Error!void {
    remote.writeDepart(name) catch return error.AnyError;
}

fn writeEntryRequest(remote: *Remote, name: []const u8) Error!void {
    remote.writeEntryRequest(name) catch return error.AnyError;
}

fn writeMessage(remote: *Remote, name: []const u8) Error!void {
    remote.writeMessage(name) catch return error.AnyError;
}

fn writeTableUpdate(remote: *Remote, table: []const u8, entry: []const u8, value: []const u8) Error!void {
    remote.writeTableUpdate(table, entry, value) catch return error.AnyError;
}

//
// Test series
//

fn doNothing(remote: *Remote, name: []const u8) Error!void {
    _ = remote;
    _ = name;
}

fn dualEntry(remote: *Remote, name: []const u8) Error!void {
    try writeEntryRequest(remote, name);
    try writeEntryRequest(remote, name);
    try writeEntryRequest(remote, name);
    try writeEntryRequest(remote, name);
    try writeEntryRequest(remote, name);
}

fn entryExit(remote: *Remote, name: []const u8) Error!void {
    try writeEntryRequest(remote, name);
    try writeDepart(remote, name);
}

fn justDepart(remote: *Remote, name: []const u8) Error!void {
    try writeDepart(remote, name);
}

fn justEntry(remote: *Remote, name: []const u8) Error!void {
    try writeEntryRequest(remote, name);
}

fn useMessage(remote: *Remote, name: []const u8) Error!void {
    try writeMessage(remote, name);
}

fn useTableUpdate(remote: *Remote, name: []const u8) Error!void {
    _ = name;
    try writeTableUpdate(remote, "does", "not", "matter");
    try writeTableUpdate(remote, "does", "not", "matter");
}

//
// Test rig
//

const TestRig = struct {
    name: []const u8,
    testfn: *const fn (remote: *Remote, name: []const u8) Error!void,
};

// TODO: some clever comptime thing
const rig = &[_]TestRig{
    .{ .name = "doNothing", .testfn = doNothing },
    .{ .name = "dualEntry", .testfn = dualEntry },
    .{ .name = "justDepart", .testfn = justDepart },
    .{ .name = "justEntry", .testfn = justEntry },
    .{ .name = "entryExit", .testfn = entryExit },
    .{ .name = "useMessage", .testfn = useMessage },
    .{ .name = "useTableUpdate", .testfn = useTableUpdate },
};

//
// Main routine
//

pub fn main() !void {
    // TODO: test name to run, etc

    var args = std.process.args();
    _ = args.skip(); // index 0 Argument is the path to the program.
    const port_value = args.next() orelse {
        log.info("Expect port as command line argument", .{});
        return error.NoPort;
    };
    const port = try std.fmt.parseInt(u16, port_value, 10);

    const peer = net.Address.parseIp4("127.0.0.1", port) catch |err| {
        log.info("Connect.init parseIp4: {}", .{err});
        return err;
    };

    //
    // Test series
    //

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    for (rig) |item| {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        const stream = net.tcpConnectToAddress(peer) catch |err| {
            log.info("tcpConnectToAddress: {}", .{err});
            return err;
        };
        const rbuf = allocator.alloc(u8, 1000) catch |err| {
            log.info("alloc read buffer: {}", .{err});
            return err;
        };
        errdefer allocator.free(rbuf);

        const name = try std.fmt.allocPrint(allocator, "{f}", .{peer});
        defer allocator.free(name);

        var reader = stream.reader(rbuf);
        var writer = stream.writer(&.{});

        var remote = Remote{
            .name = name,
            .reader = reader.interface(),
            .writer = &writer.interface,
        };

        log.info("* * * START {s} * * *", .{item.name});
        try item.testfn(&remote, item.name);
        log.info("* * * END {s} * * *", .{item.name});
    }

    log.info("Test series complete", .{});
}
