//!
//! input/output Provider, plus Mock for testing
//!
//! Mock Input/Display provider for testing
//!

const std = @import("std");
const Provider = @import("Provider.zig");
const Command = @import("roguelib").Command;

const Self = @This();

//
// Types
//

pub const Config = struct {
    maxx: i16,
    maxy: i16,
    // commands: []Command, // TODO
};

//
// Members
//

p: Provider = undefined,
// allocator: std.mem.Allocator,
// command_list: []Command = undefined, // TODO
// command_index: u16 = 0,  // TODO

//
// Constructor / Destructor
//

pub fn init(config: Config) Self {
    return .{
        .p = .{
            .ptr = undefined,
            .x = config.maxx,
            .y = config.maxy,
            .vtable = &.{
                .getCommand = getCommand,
            },
        },
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
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

fn getCommand(ptr: *anyopaque) Command {
    // const self: *MockProvider = @ptrCast(@alignCast(ptr));
    _ = ptr;
    return .wait;
}

//
// Unit tests
//

const expect = std.testing.expect;

test "try out mock" {
    var m = init(.{ .maxx = 40, .maxy = 60 });
    defer m.deinit();

    var p = m.provider();
    try expect(p.getCommand() == .wait);
}

// EOF
