//!
//! zrogue client-server fuzz testing
//!

const std = @import("std");
const server = @import("root.zig");
const log = std.log;
const net = std.net;

const Remote = server.Remote;

// TODO: boilerplate
fn writeAction(remote: *Remote, kind: server.Action.Kind, pos: []const i16) void {
    var alloc_b: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = server.Action.init(fba.allocator(), kind, pos) catch unreachable;
    // abandoned
    server.writeAction(remote, msg.*) catch unreachable;
}

fn writeDepart(remote: *Remote, text: []const u8) void {
    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = server.Depart.init(fba.allocator(), text) catch unreachable;
    // abandoned
    server.writeDepart(remote, msg.*) catch unreachable;
}

fn writeEntryRequest(remote: *Remote, text: []const u8) void {
    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = server.EntryRequest.init(fba.allocator(), text) catch unreachable;
    // abandoned
    server.writeEntryRequest(remote, msg.*) catch unreachable;
}

fn writeMessage(remote: *Remote, text: []const u8) void {
    var alloc_b: [100]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = server.Message.init(fba.allocator(), text) catch unreachable;
    // abandoned
    server.writeMessage(remote, msg.*) catch unreachable;
}

fn writeMapUpdate(remote: *Remote) void {
    const update = server.MapUpdate{ // TODO: phooey
        .x = 0,
        .y = 1,
        .tile = .{
            .entity = .unknown,
            .item = .gold,
            .floor = .wall,
            .visible = true,
        },
    };
    server.writeMapUpdate(remote, update) catch unreachable;
}

fn writeTableUpdate(remote: *Remote, table: []const u8, entry: []const u8, value: []const u8) void {
    var alloc_b: [200]u8 = undefined; // Calculated
    var fba = std.heap.FixedBufferAllocator.init(&alloc_b);
    const msg = server.TableUpdate.init(fba.allocator(), table, entry, value) catch unreachable;
    // abandoned
    server.writeTableUpdate(remote, msg.*) catch unreachable;
}

//
// Test series
//

fn doNothing(remote: *Remote, name: []const u8) void {
    _ = remote;
    _ = name;
}

fn dualEntry(remote: *Remote, name: []const u8) void {
    writeEntryRequest(remote, name);
    writeEntryRequest(remote, name);
    writeEntryRequest(remote, name);
    writeEntryRequest(remote, name);
    writeEntryRequest(remote, name);
}

fn entryExit(remote: *Remote, name: []const u8) void {
    writeEntryRequest(remote, name);
    writeAction(remote, .none, &.{ 0, 0 });
    writeDepart(remote, name);
}

fn justDepart(remote: *Remote, name: []const u8) void {
    writeDepart(remote, name);
}

fn justEntry(remote: *Remote, name: []const u8) void {
    writeEntryRequest(remote, name);
}

fn useMessage(remote: *Remote, name: []const u8) void {
    writeMessage(remote, name);
}

fn useTableUpdate(remote: *Remote, name: []const u8) void {
    _ = name;
    writeTableUpdate(remote, "does", "not", "matter");
    writeTableUpdate(remote, "does", "not", "matter");
}

fn justAction(remote: *Remote, name: []const u8) void {
    _ = name;
    writeAction(remote, .none, &.{ 0, 0 });
}

fn useMapUpdate(remote: *Remote, name: []const u8) void {
    _ = name;
    writeMapUpdate(remote);
    writeMapUpdate(remote);
}

//
// Test rig
//

const TestRig = struct {
    name: []const u8,
    testfn: *const fn (remote: *Remote, name: []const u8) void,
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
    .{ .name = "justAction", .testfn = justAction },
    .{ .name = "useMapUpdate", .testfn = useMapUpdate },
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
        item.testfn(&remote, item.name);
        log.info("* * * END {s} * * *", .{item.name});
    }

    log.info("Test series complete", .{});
}
