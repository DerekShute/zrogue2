//!
//! Mock Input/Display provider for testing
//!

const std = @import("std");
const Provider = @import("ui").Provider;

const Self = @This();

//
// Types
//

pub const Config = struct {
    allocator: std.mem.Allocator,
    maxx: u8,
    maxy: u8,
    commands: []Provider.Command,
};

//
// Members
//

p: Provider = undefined,
command_list: []Provider.Command = undefined,
command_index: u16 = 0,
notified: bool = false,

//
// Constructor / Destructor
//

pub fn init(config: Config) !Self {
    const pc: Provider.Config = .{
        .allocator = config.allocator,
        .maxx = config.maxx,
        .maxy = config.maxy,
        .vtable = &.{
            .getCommand = mockGetCommand,
            .notifyDisplay = mockNotifyDisplay,
        },
    };

    return .{
        .p = try Provider.init(pc),
        .command_list = config.commands,
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.p.deinit(allocator);
    return;
}

//
// Lifecycle
//

pub fn provider(self: *Self) *Provider {
    self.p.ptr = self;
    return &self.p;
}

//
// VTable
//

fn mockGetCommand(ptr: *anyopaque) Provider.Command {
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

//
// Methods for testing convenience
//

pub fn getPurse(self: *Self) u16 {
    return self.p.getStats().purse;
}

pub fn getDepth(self: *Self) usize {
    return self.p.getStats().depth;
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

var testlist = [_]Provider.Command{
    .go_west,
    .quit,
};

test "try out mock" {
    const stats: Provider.Stats = .{
        .purse = 10,
        .depth = 1,
    };
    var m = try init(.{ .allocator = std.testing.allocator, .maxx = 40, .maxy = 60, .commands = &testlist });
    defer m.deinit(std.testing.allocator);

    var p = m.provider();
    try expect(p.getCommand() == .go_west);

    try expect(p.getStats().purse == 0);
    try expect(p.getStats().depth == 0);
    try expect(!m.getNotified());
    p.updateStats(stats);
    try expect(p.getStats().purse == 10);
    try expect(p.getStats().depth == 1);
    try expect(m.getNotified());
}

test "mock alloc does not work 0" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(.{ .allocator = failing.allocator(), .maxx = 40, .maxy = 60, .commands = &testlist }));
}

// EOF
