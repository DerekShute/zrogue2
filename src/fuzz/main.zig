//!
//! zrogue client-server fuzz testing
//!

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log;
const net = std.Io.net;

const Command = @import("roguelib").Command;
const MapTile = @import("roguelib").MapTile;
const Connector = @import("connector");

fn doNothing(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    _ = connect;
    _ = name;
}

fn dualEntry(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    connect.writeEntryRequest(name) catch return;
    connect.writeEntryRequest(name) catch return;
    connect.writeEntryRequest(name) catch return;
    connect.writeEntryRequest(name) catch return;
    connect.writeEntryRequest(name) catch return;
}

fn entryExit(allocator: Allocator, connect: *Connector, name: []const u8) void {
    connect.writeEntryRequest(name) catch return;
    connect.writeCommandMsg(@intFromEnum(Command.wait)) catch return;
    connect.run(allocator) catch return;
    connect.writeDepart(name) catch return;
}

fn justDepart(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    connect.writeDepart(name) catch return;
}

fn justEntry(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    connect.writeEntryRequest(name) catch return;
}

fn useMessage(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    connect.writeMessage(name) catch return;
}

fn useTableUpdate(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    _ = name;
    connect.writeTableUpdate("does", "not", "matter") catch return;
    connect.writeTableUpdate("does", "not", "matter") catch return;
}

fn useMapUpdate(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    _ = name;
    const tile = Connector.Tile{
        .entity = @intFromEnum(MapTile.unknown),
        .item = @intFromEnum(MapTile.gold),
        .floor = @intFromEnum(MapTile.wall),
        .visible = true,
    };

    var pos: [2]i16 = .{ 0, 1 };

    connect.writeMapUpdate(&pos, tile) catch return;
}

//
// Test rig
//

const TestRig = struct {
    name: []const u8,
    testfn: *const fn (allocator: Allocator, connect: *Connector, name: []const u8) void,
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

fn command(ctx: *anyopaque, cmd: u16) !void {
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

fn updateMap(ctx: *anyopaque, pos: [2]i16, tile: Connector.Tile) !void {
    _ = ctx;
    _ = pos;
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

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) {
        std.debug.print("Expect port as command line argument\n", .{});
        return;
    }

    const port = try std.fmt.parseInt(u16, args[1], 10);
    const peer = net.IpAddress.parseIp4("127.0.0.1", port) catch |err| {
        log.info("Connect.init parseIp4: {}", .{err});
        return err;
    };

    //
    // Test series
    //

    for (rig) |item| {
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        const allocator = arena.allocator();

        const stream = peer.connect(init.io, .{ .mode = .stream }) catch |err| {
            log.info("tcpConnectToAddress: {}", .{err});
            return err;
        };
        defer stream.close(init.io);

        const rbuf = allocator.alloc(u8, 1000) catch |err| {
            log.info("alloc read buffer: {}", .{err});
            return err;
        };

        var reader = stream.reader(init.io, rbuf);
        var writer = stream.writer(init.io, &.{});

        var connector = Connector{
            .vt = &vt,
            // .ctx ignored do not reference
            .reader = &reader.interface,
            .writer = &writer.interface,
        };

        log.info("* * * START {s} * * *", .{item.name});
        item.testfn(allocator, &connector, item.name);
        log.info("* * * END {s} * * *", .{item.name});
    }

    log.info("Test series complete", .{});
}
