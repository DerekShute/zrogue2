const std = @import("std");
const msgpack = @import("msgpack");

const Reader = std.io.Reader;
const Writer = std.io.Writer;

pub fn genericWrite(msg: anytype, writer: *Writer) !void {
    var buffer: [100]u8 = undefined;
    var bwriter = std.io.Writer.fixed(&buffer);
    try msgpack.encode(msg, &bwriter);
    try writer.writeAll(bwriter.buffered());
    try writer.flush();
}

pub fn genericRead(T: type, reader: *Reader, allocator: std.mem.Allocator) !*T {
    // Uses a constrained allocator here to prevent malicious actors
    var buffer: [250]u8 = undefined; // Calculated size
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    var msg = try msgpack.decode(T, fba.allocator(), reader);
    // error.OutOfMemory -> message could be too long

    if (!msg.value.valid()) { // Borderline but enforce
        return error.OutOfMemory;
    }
    return try T.copy(allocator, msg.value);
}

// EOF
