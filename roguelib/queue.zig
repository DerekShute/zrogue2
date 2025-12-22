//!
//! Queue of elements
//!
//! For the action queue, for instance
//!

const std = @import("std");

const List = std.DoublyLinkedList;

//
// Types
//

pub const Node = List.Node;

pub fn Queue(comptime T: type, comptime field_name: []const u8) type {
    return struct {
        const Self = @This();

        list: List = undefined,

        pub fn config() Self {
            return .{
                .list = .{},
            };
        }

        pub fn enqueue(self: *Self, new: *T) void {
            self.list.append(&@field(new, field_name));
        }

        pub fn dequeue(self: *Self, rid: *T) void {
            self.list.remove(&@field(rid, field_name));
        }

        pub fn next(self: *Self) ?*T {
            if (self.list.popFirst()) |node| {
                return @fieldParentPtr(field_name, node);
            }
            return null;
        }
    };
}

//
// Unit Tests
//

const expect = std.testing.expect;

const Test = struct {
    data: u32,
    node: Node = .{},
};

const TestQueue = Queue(Test, "node");

test "basics" {
    var tq = TestQueue.config();

    var node1: Test = .{ .data = 0 };
    var node2: Test = .{ .data = 1 };
    var node3: Test = .{ .data = 2 };

    tq.enqueue(&node1);
    tq.enqueue(&node2);
    tq.enqueue(&node3);

    tq.dequeue(&node1);
    try expect(tq.next() == &node2);
    try expect(tq.next() == &node3);
    try expect(tq.next() == null);
}

// EOF
