//!
//! zrogue client-server fuzz testing
//!

const std = @import("std");
const server = @import("root.zig");
const net = std.net;

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

// TODO more sensitive use
const log = std.log.scoped(.fuzz);

//
// Connect : connection-to-server abstraction
//
const Connect = struct {
    rbuf: []u8 = undefined,
    stream: net.Stream = undefined,

    const Self = @This();

    pub fn init(allocator: Allocator, port: u16) Self {
        var self: Self = .{};

        const peer = net.Address.parseIp4("127.0.0.1", port) catch |err| {
            log.info("Connect.init parseIp4: {}", .{err});
            @panic("Connect.init");
        };
        log.info("Connecting to {f}", .{peer});

        // TODO: ConnectionRefused
        self.stream = net.tcpConnectToAddress(peer) catch |err| {
            log.info("Connect.init tcpConnectToAddress: {}", .{err});
            @panic("Connect.init");
        };
        self.rbuf = allocator.alloc(u8, 1000) catch |err| {
            log.info("Connect.init alloc read buffer: {}", .{err});
            @panic("Connect.init");
        };
        errdefer allocator.free(self.rbuf);

        return self;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.stream.close();
        allocator.free(self.rbuf);
    }

    //
    // Methods
    //

    pub fn writeEntryRequest(self: *Self, name: []const u8) void {
        var writer = self.stream.writer(&.{});
        server.writeEntryRequest(&writer.interface, name) catch |err| {
            log.info("writeEntryRequest: {}", .{err});
            @panic("writeEntryRequest");
        };
    }

    pub fn writeDepart(self: *Self, msg: []const u8) void {
        var writer = self.stream.writer(&.{});
        server.writeDepart(&writer.interface, msg) catch |err| {
            log.info("writeDepart: {}", .{err});
            @panic("writeDepart");
        };
    }

    pub fn writeMessage(self: *Self, msg: []const u8) void {
        var writer = self.stream.writer(&.{});
        server.writeMessage(&writer.interface, msg) catch |err| {
            log.info("writeDepart: {}", .{err});
            @panic("writeDepart");
        };
    }
};

//
// Test series
//

fn doNothing(connect: *Connect, name: []const u8) void {
    _ = connect;
    _ = name;
}

fn dualEntry(connect: *Connect, name: []const u8) void {
    connect.writeEntryRequest(name);
    connect.writeEntryRequest(name);
    connect.writeEntryRequest(name);
    connect.writeEntryRequest(name);
    connect.writeEntryRequest(name);
}

fn entryExit(connect: *Connect, name: []const u8) void {
    connect.writeEntryRequest(name);
    connect.writeDepart(name);
}

fn justDepart(connect: *Connect, name: []const u8) void {
    connect.writeDepart(name);
}

fn justEntry(connect: *Connect, name: []const u8) void {
    connect.writeEntryRequest(name);
}

fn useMessage(connect: *Connect, name: []const u8) void {
    connect.writeMessage(name);
}

//
// Test rig
//

const TestFn = *const fn (connect: *Connect, name: []const u8) void;

const TestRig = struct {
    name: []const u8,
    testfn: TestFn,
};

// TODO: some clever comptime thing
const rig = &[_]TestRig{
    .{ .name = "doNothing", .testfn = doNothing },
    .{ .name = "dualEntry", .testfn = dualEntry },
    .{ .name = "justDepart", .testfn = justDepart },
    .{ .name = "justEntry", .testfn = justEntry },
    .{ .name = "entryExit", .testfn = entryExit },
    .{ .name = "useMessage", .testfn = useMessage },
};

//
// Main routine
//

// TODO: Catch panic

pub fn main() !void {
    // TODO: test name to run, etc

    var args = std.process.args();
    _ = args.skip(); // index 0 Argument is the path to the program.
    const port_value = args.next() orelse {
        log.info("Expect port as command line argument", .{});
        return error.NoPort;
    };
    const port = try std.fmt.parseInt(u16, port_value, 10);

    //
    // Test series
    //
    // TODO: as an array with loop?
    //

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    for (rig) |item| {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        var connect = Connect.init(arena.allocator(), port);
        defer connect.deinit(arena.allocator());

        log.info("* * * START {s} * * *", .{item.name});
        item.testfn(&connect, item.name);
        log.info("* * * END {s} * * *", .{item.name});
    }

    log.info("Test series complete", .{});
}
