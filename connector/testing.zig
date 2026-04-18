//!
//! Testing apparatus for the Connector
//!

const std = @import("std");
const Connector = @import("root.zig");

const Writer = std.Io.Writer;
const Reader = std.Io.Reader;

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;
const print = std.debug.print;

const TestFramework = struct {
    got_entry: bool = false,
    got_message: bool = false,
    got_unsupported: bool = false,
};

//
// Callbacks and dispatch table
//

fn gotUnsupported(ctx: *anyopaque) Connector.Error!void {
    const self: *TestFramework = @ptrCast(@alignCast(ctx));
    self.got_unsupported = true;
    return error.Invalid;
}

fn gotEntry(ctx: *anyopaque, msg: []const u8) Connector.Error!void {
    const self: *TestFramework = @ptrCast(@alignCast(ctx));
    _ = msg;
    self.got_entry = true;
}

fn gotMessage(ctx: *anyopaque, msg: []const u8) Connector.Error!void {
    const self: *TestFramework = @ptrCast(@alignCast(ctx));
    _ = msg;
    self.got_message = true;
    return error.Failed;
}

const vt = Connector.VTable{
    .unsupported = gotUnsupported,
    .entry = gotEntry,
    .updateMessage = gotMessage,
};

//
// The Tests
//

test "basic use" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var frame: TestFramework = .{};

    var connect = Connector{
        .ctx = &frame,
        .vt = &vt,
        .reader = &breader,
        .writer = &bwriter,
    };

    try connect.writeEntryRequest("a test");

    // Dirty trick
    breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    connect.reader = &breader;

    try connect.run(t_allocator);

    try expect(frame.got_entry);
}

test "unsupported" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var frame: TestFramework = .{};

    var connect = Connector{
        .ctx = &frame,
        .vt = &vt,
        .reader = &breader,
        .writer = &bwriter,
    };

    try connect.writeTableUpdate("a test", "a test", "a test");

    // Dirty trick
    breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    connect.reader = &breader;

    try expectError(error.Invalid, connect.run(t_allocator));
    try expect(frame.got_unsupported);
}

test "internal failure" {
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var frame: TestFramework = .{};

    var connect = Connector{
        .ctx = &frame,
        .vt = &vt,
        .reader = &breader,
        .writer = &bwriter,
    };

    try connect.writeMessage("a test");

    // Dirty trick
    breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    connect.reader = &breader;

    try expectError(error.Failed, connect.run(t_allocator));
    try expect(frame.got_message);
}

comptime {
    _ = @import("CommandMessage.zig");
    _ = @import("MapUpdate.zig");
    _ = @import("TableUpdate.zig");
    _ = @import("TextMessage.zig");
}

// EOF
