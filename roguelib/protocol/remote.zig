//!
//! Message passing atomics using msgpack
//!

const std = @import("std");
const msgpack = @import("msgpack");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

//
// Types
//

pub const Error = error{
    Failed,
    Invalid,
};

//
// Messaging wrappers
//

pub fn Write(comptime T: type, comptime MT: u16) type {
    // You can return the function body as '.write' here but that makes the
    // return type very complicated.
    return struct {
        pub fn write(writer: *Writer, msg: T) !void {
            var intbuf: [2]u8 = undefined;
            std.mem.writeInt(u16, &intbuf, MT, .big);
            try writer.writeAll(intbuf[0..]);
            // TODO: write size of message - need to encode it
            try msgpack.encode(msg, writer);
            try writer.flush();
        }
    };
}

// Clients implement ReadFn
pub const ReadFn = *const fn (ctx: *anyopaque, ptr: *anyopaque) Error!void;

// Internal

pub const DispatchReadFn = *const fn (reader: *Reader, ctx: *anyopaque, allocator: Allocator) Error!void;

pub fn Read(comptime T: type, comptime FN: ReadFn) type {
    return struct {
        // NOTE: allocator is fixed buffer or arena and must be squashed
        pub fn read(reader: *Reader, ctx: *anyopaque, allocator: Allocator) !void {
            var msg = msgpack.decode(T, allocator, reader) catch {
                return error.Failed;
            };
            defer msg.deinit();

            if (!msg.value.valid()) {
                return error.Invalid;
            }

            try FN(ctx, &msg.value);
        }
    };
}

//
// Unit Testing
//

// NOCOMMIT

// EOF
