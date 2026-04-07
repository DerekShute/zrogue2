//!
//! zrogue client-server fuzz testing
//!

const std = @import("std");
const log = std.log;
const net = std.net;

const Connector = @import("roguelib").Connector;

fn doNothing(connect: *Connector, name: []const u8) void {
    _ = connect;
    _ = name;
}

fn dualEntry(connect: *Connector, name: []const u8) void {
    connect.writeEntryRequest(name) catch return;
    connect.writeEntryRequest(name) catch return;
    connect.writeEntryRequest(name) catch return;
    connect.writeEntryRequest(name) catch return;
    connect.writeEntryRequest(name) catch return;
}

fn entryExit(connect: *Connector, name: []const u8) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    connect.writeEntryRequest(name) catch return;
    connect.writeCommandMsg(.wait) catch return;
    connect.run(allocator) catch return;
    connect.writeDepart(name) catch return;
}

fn justDepart(connect: *Connector, name: []const u8) void {
    connect.writeDepart(name) catch return;
}

fn justEntry(connect: *Connector, name: []const u8) void {
    connect.writeEntryRequest(name) catch return;
}

fn useMessage(connect: *Connector, name: []const u8) void {
    connect.writeMessage(name) catch return;
}

fn useTableUpdate(connect: *Connector, name: []const u8) void {
    _ = name;
    connect.writeTableUpdate("does", "not", "matter") catch return;
    connect.writeTableUpdate("does", "not", "matter") catch return;
}

fn justAction(connect: *Connector, name: []const u8) void {
    _ = name;
    connect.writeAction(.none, &.{ 0, 0 }) catch return;
}

fn useMapUpdate(connect: *Connector, name: []const u8) void {
    _ = name;
    const tile = Connector.Tile{
        .entity = .unknown,
        .item = .gold,
        .floor = .wall,
        .visible = true,
    };

    connect.writeMapUpdate(&.{ 0, 1 }, tile) catch return;
}

//
// Test rig
//

const TestRig = struct {
    name: []const u8,
    testfn: *const fn (connect: *Connector, name: []const u8) void,
};

// The names of the test functions to execute
//
// In deep theory the 'make' can look up the declarations via comptime
// reflection but that creates a storage problem for the name strings.  It
// would be clever, though.
//
const functions = .{
    "doNothing",
    "dualEntry",
    "justDepart",
    "justEntry",
    "entryExit",
    "useMessage",
    "useTableUpdate",
    "justAction",
    "useMapUpdate",
};

// Convert the array of names to function bodies and assemble the rig
fn make(comptime fns: anytype) [fns.len]TestRig {
    var entries: [fns.len]TestRig = undefined;
    inline for (fns, 0..) |function, index| {
        entries[index] = .{
            .name = function,
            .testfn = @field(@This(), function),
        };
    }
    return entries;
}

const rig = make(functions); // Your rig

//
// Phony things
//

fn command(ctx: *anyopaque, cmd: Connector.Command) !void {
    _ = ctx;
    _ = cmd;
}

fn depart(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    _ = text;
}

fn entryRequest(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    _ = text;
}

fn updateMap(ctx: *anyopaque, x: i16, y: i16, tile: Connector.Tile) !void {
    _ = ctx;
    _ = x;
    _ = y;
    _ = tile;
    std.debug.print("map update\n", .{});
}

fn updateMessage(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    std.debug.print("message: '{s}'\n", .{text});
}

fn updateTable(ctx: *anyopaque, table: []const u8, entry: []const u8, value: []const u8) !void {
    _ = ctx;
    _ = table;
    _ = entry;
    _ = value;
    std.debug.print("table update\n", .{});
}

fn unsupported(ctx: *anyopaque) !void {
    _ = ctx;
    return;
}

var vt = Connector.VTable{
    .command = command,
    .depart = depart,
    .entry = entryRequest,
    .updateMap = updateMap,
    .updateMessage = updateMessage,
    .updateTable = updateTable,
    .unsupported = unsupported,
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

        var connector = Connector{
            .vt = &vt,
            // .ctx ignored do not reference
            .reader = reader.interface(),
            .writer = &writer.interface,
        };

        log.info("* * * START {s} * * *", .{item.name});
        item.testfn(&connector, item.name);
        log.info("* * * END {s} * * *", .{item.name});
    }

    log.info("Test series complete", .{});
}
