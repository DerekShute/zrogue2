//!
//! zrogue client-server fuzz testing
//!

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log;
const IpAddress = std.Io.net.IpAddress;

const Command = @import("roguelib").Command;
const MapTile = @import("roguelib").MapTile;
const Connector = @import("connector");

//
// Test elements
//

fn doNothing(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    _ = connect;
    _ = name;
}

fn dualEntry(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    connect.writeEntryRequest(name) catch return;
    connect.writeEntryRequest("Second") catch return;
}

fn entryExit(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    connect.writeEntryRequest(name) catch return;
    connect.writeDepart(name) catch return;
}

fn justDepart(allocator: Allocator, connect: *Connector, name: []const u8) void {
    _ = allocator;
    connect.writeDepart(name) catch return;
}

fn justEntry(allocator: Allocator, connect: *Connector, name: []const u8) void {
    // There'd need to be an explicit disconnect of some kind to trigger
    // closure of the listener thread, so this doesn't work

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
    var pos: [2]i16 = .{ 0, 1 };
    connect.writeMapUpdate(&pos, Connector.DisplayTile.init) catch return;
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
    "dualEntry",
    "justDepart",
    // "justEntry",
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
// Connector callbacks
//

fn depart(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    log.info("Depart: {s}", .{text});
}

fn updateMap(ctx: *anyopaque, pos: [2]i16, tile: Connector.DisplayTile) !void {
    _ = ctx;
    _ = tile;
    _ = pos;
    //    log.info("updateMap: {}:{}", .{ pos[0], pos[1] });
}

fn updateMessage(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    log.info("Message: {s}", .{text});
}

fn updateTable(ctx: *anyopaque, table: []const u8, entry: []const u8, value: []const u8) !void {
    _ = ctx;
    log.info("updateTable: {s} : {s} : {s}", .{ table, entry, value });
}

fn unsupported(ctx: *anyopaque) !void {
    _ = ctx;
    log.info("Unsupported!", .{});
}

var vt = Connector.VTable{
    .depart = depart,
    .updateMap = updateMap,
    .updateMessage = updateMessage,
    .updateTable = updateTable,
    .unsupported = unsupported,
};

//
// Execution
//

fn runThread(connector: *Connector, allocator: Allocator) !void {
    while (true) {
        connector.run(allocator) catch |err| switch (err) {
            // Enumerating errors as seen
            error.EndOfStream => return,
            error.ReadFailed => return,
            else => return err,
        };
    }
}

fn run(io: std.Io, allocator: Allocator, item: TestRig, peer: IpAddress) !void {
    const stream = peer.connect(io, .{ .mode = .stream }) catch |err| {
        log.info("tcpConnectToAddress: {}", .{err});
        return err;
    };
    defer stream.close(io);

    const rbuf = allocator.alloc(u8, 1000) catch |err| {
        log.info("alloc read buffer: {}", .{err});
        return err;
    };

    var reader = stream.reader(io, rbuf);
    var writer = stream.writer(io, &.{});

    var connector = Connector{
        .vt = &vt,
        // .ctx ignored do not reference
        .reader = &reader.interface,
        .writer = &writer.interface,
    };

    const thread = try std.Thread.spawn(
        .{},
        runThread,
        .{ &connector, allocator },
    );
    defer thread.join();

    // TODO: do nothing gets trapped. Why?

    item.testfn(allocator, &connector, item.name);
}

//
// Main routine
//

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 2) {
        std.debug.print("Expect port as command line argument\n", .{});
        return;
    }

    const port = try std.fmt.parseInt(u16, args[1], 10);
    const peer = std.Io.net.IpAddress.parseIp4("127.0.0.1", port) catch |err| {
        log.info("Connect.init parseIp4: {}", .{err});
        return err;
    };

    //
    // Test series
    //

    for (rig) |item| {
        log.info("* * * START {s} * * *", .{item.name});
        run(init.io, arena, item, peer) catch |err| switch (err) {
            error.ConnectionRefused => {
                log.info("Connection refused.  Server listening?", .{});
                return;
            },
            else => return err,
        };
        log.info("* * * END {s} * * *", .{item.name});
    }

    log.info("Test series complete", .{});
}
