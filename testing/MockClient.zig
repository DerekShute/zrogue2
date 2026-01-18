//!
//! Mock Input/Display provider for testing
//!

const std = @import("std");
const Client = @import("roguelib").Client;

const Self = @This();

//
// Types
//

pub const Config = struct {
    allocator: std.mem.Allocator,
    maxx: u8,
    maxy: u8,
    commands: []Client.Command,
};

//
// Members
//

c: Client = undefined,
command_list: []Client.Command = undefined,
command_index: u16 = 0,
notified: bool = false,
purse: i32 = 0,
depth: i32 = 0,

//
// Constructor / Destructor
//

pub fn init(config: Config) !Self {
    const pc: Client.Config = .{
        .allocator = config.allocator,
        .maxx = config.maxx,
        .maxy = config.maxy,
        .vtable = &.{
            .getCommand = mockGetCommand,
            .notifyDisplay = mockNotifyDisplay,
            .setStatInt = mockSetStatInt,
        },
    };

    return .{
        .c = try Client.init(pc),
        .command_list = config.commands,
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.c.deinit(allocator);
    return;
}

//
// Lifecycle
//

pub fn client(self: *Self) *Client {
    self.c.ptr = self;
    return &self.c;
}

//
// VTable
//

fn mockGetCommand(ptr: *anyopaque) Client.Command {
    const self: *Self = @ptrCast(@alignCast(ptr));
    const i = self.command_index;
    if (i >= self.command_list.len) {
        @panic("No more mock commands to provide");
    }
    self.command_index += 1;
    return self.command_list[i];
}

fn mockNotifyDisplay(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.notified = true;
}

fn mockSetStatInt(ptr: *anyopaque, name: []const u8, value: i32) void {
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (std.mem.eql(u8, "purse", name)) {
        self.purse = value;
    } else if (std.mem.eql(u8, "depth", name)) {
        self.depth = value;
    } else {
        @panic("mockSetStatInt: Unsupported name");
    }
}

//
// Methods for testing convenience
//

pub fn getStatPurse(self: *Self) i32 {
    return self.purse;
}

pub fn getStatDepth(self: *Self) i32 {
    return self.depth;
}

pub fn getNotified(self: *Self) bool {
    // Turns itself off for your convenience
    const was = self.notified;
    self.notified = false;
    return was;
}
//
// Unit tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;

var testlist = [_]Client.Command{
    .go_west,
    .quit,
};

test "try out mock" {
    var m = try init(.{ .allocator = std.testing.allocator, .maxx = 40, .maxy = 60, .commands = &testlist });
    defer m.deinit(std.testing.allocator);

    var c = m.client();
    try expect(c.getCommand() == .go_west);

    try expect(m.getStatPurse() == 0);
    try expect(m.getStatDepth() == 0);
    try expect(!m.getNotified());

    c.setStatInt("purse", 10);
    try expect(m.getStatPurse() == 10);
    c.setStatInt("depth", 4);
    try expect(m.getStatDepth() == 4);
}

test "mock alloc does not work 0" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(.{ .allocator = failing.allocator(), .maxx = 40, .maxy = 60, .commands = &testlist }));
}

test "display map range iterator" {
    var m = try init(.{ .allocator = std.testing.allocator, .maxx = 100, .maxy = 100, .commands = &testlist });
    defer m.deinit(std.testing.allocator);

    var c = m.client();
    if (c.displayChange()) |dc| {
        var _dc = dc; // Convert from const
        while (_dc.next()) |loc| {
            try expect((loc.getX() >= 0) and (loc.getY() < 100));
            try expect((loc.getY() >= 0) and (loc.getY() < 100));
        }
    }
    // TODO should hit each one
}

// EOF
