//!
//! input/output Provider, plus Mock for testing
//!
//! Mock Input/Display provider for testing
//!

const std = @import("std");
const Provider = @import("Provider.zig");

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

//
// Constructor / Destructor
//

pub fn init(config: Config) !Self {
    const pc: Provider.Config = .{
        .allocator = config.allocator,
        .maxx = config.maxx,
        .maxy = config.maxy,
        .vtable = &.{
            .getCommand = getCommand,
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
// Methods
//

fn getCommand(ptr: *anyopaque) Provider.Command {
    const self: *Self = @ptrCast(@alignCast(ptr));
    const i = self.command_index;
    if (i >= self.command_list.len) {
        @panic("No more mock commands to provide");
    }
    self.command_index += 1;
    return self.command_list[i];
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
    var m = try init(.{ .allocator = std.testing.allocator, .maxx = 40, .maxy = 60, .commands = &testlist });
    defer m.deinit(std.testing.allocator);

    var p = m.provider();
    try expect(p.getCommand() == .go_west);
}

test "mock alloc does not work 0" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(.{ .allocator = failing.allocator(), .maxx = 40, .maxy = 60, .commands = &testlist }));
}

test "mock alloc does not work 1" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    try expectError(error.OutOfMemory, init(.{ .allocator = failing.allocator(), .maxx = 40, .maxy = 60, .commands = &testlist }));
}

// EOF
