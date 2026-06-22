//!
//! Generate visualization of common structures
//!

// https://ziggit.dev/t/error-when-generating-struct-field-names-using-zig-comptime/6319/2

const std = @import("std");
const comptimePrint = std.fmt.comptimePrint;

pub fn genFields(comptime T: type) []const []const u8 {
    const typeInfo = @typeInfo(T);
    switch (typeInfo) {
        .@"struct" => |structInfo| {
            const field_count = structInfo.fields.len;
            var names: [field_count + 1][]const u8 = undefined;
            names[0] = comptimePrint("{s}:", .{@typeName(T)});
            for (structInfo.fields, 1..) |field, i| {
                const type_string = comptimePrint("{}", .{field.type});
                // Remove internal double quotes to not confuse YAML
                const edited_type = comptime blk: {
                    const size = std.mem.replacementSize(u8, type_string, "\"", "'");
                    var buffer: [128]u8 = undefined;
                    _ = std.mem.replace(
                        u8,
                        type_string,
                        "\"",
                        "'",
                        &buffer,
                    );
                    break :blk buffer[0..size];
                };
                names[i] = comptimePrint("  {s}: \"{s}\"", .{ field.name, edited_type });
            }
            // for (structInfo.decls, field_count + 1..) |decl, i| {
            //     names[i] = comptimePrint("  {s}: \"(decl)\"", .{decl.name});
            // }
            const frozen = names;
            return &frozen;
        },
        else => @compileError("Only structs are supported!"),
    }
}

// EOF
