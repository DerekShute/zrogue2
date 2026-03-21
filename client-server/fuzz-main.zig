//!
//! zrogue client-server fuzz testing
//!

const std = @import("std");
const server = @import("root.zig");
const log = std.log;
const net = std.net;

const Remote = server.Remote;

//
// Eat errors because these can be called from callback function pointers
//
// This should be compiled with full debug protections
//

fn Wrap(comptime T: type, comptime MT: server.MessageType) type {
    return struct {
        pub fn write(remote: *Remote, msg: T) void {
            const r_write = Remote.Write(T, @intFromEnum(MT)).write;
            r_write(remote, msg) catch unreachable;
        }
    };
}

fn writeAction(remote: *Remote, kind: server.ActionMsg.Type, pos: []const i16) void {
    const write = Wrap(server.ActionMsg, .action).write;
    write(remote, .{ .x = pos[0], .y = pos[1], .kind = kind });
}

fn writeDepart(remote: *Remote, text: []const u8) void {
    const write = Wrap(server.Depart, .depart).write;
    write(remote, .{ .message = text });
}

fn writeEntryRequest(remote: *Remote, text: []const u8) void {
    const write = Wrap(server.EntryRequest, .entry_request).write;
    write(remote, .{ .name = text });
}

fn writeMessage(remote: *Remote, text: []const u8) void {
    const write = Wrap(server.Message, .message).write;
    write(remote, .{ .message = text });
}

fn writeMapUpdate(remote: *Remote) void {
    const write = Wrap(server.MapUpdate, .map_update).write;
    const tile = server.MapUpdate.DisplayTile{
        .entity = .unknown,
        .item = .gold,
        .floor = .wall,
        .visible = true,
    };

    write(remote, .{ .x = 0, .y = 1, .tile = tile });
}

fn writeTableUpdate(remote: *Remote, table: []const u8, entry: []const u8, value: []const u8) void {
    const write = Wrap(server.TableUpdate, .table_update).write;
    write(remote, .{ .table = table, .entry = entry, .value = value });
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
            .reader = reader.interface(),
            .writer = &writer.interface,
        };

        log.info("* * * START {s} * * *", .{item.name});
        item.testfn(&remote, item.name);
        log.info("* * * END {s} * * *", .{item.name});
    }

    log.info("Test series complete", .{});
}
