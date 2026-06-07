//!
//! Field of Vision grid
//!
//! This only handles natural vision, not clairvoyant sensing
//!

const std = @import("std");
const Grid = @import("grid.zig").Grid;
const Pos = @import("Pos.zig");
const Region = @import("Region.zig");

//
// Types
//

const Self = @This();

const Tile = struct {
    visible: bool, // Tile is currently visible
    changed: bool, // Map has changed or knowledge/visibility has

    const init: Tile = .{
        .visible = false,
        .changed = false,
    };
};

const FOVGrid = Grid(Tile);

//
// Members
//

grid: FOVGrid = undefined,
max: Pos = undefined,
// TODO: top-changed, bottom-changed

//
// Lifecycle
//

pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Self {
    const g = try FOVGrid.config(allocator, width, height);
    errdefer g.deinit(allocator);

    // TODO almost certainly comptime known
    if (width > std.math.maxInt(Pos.Dim)) {
        @panic("FOVMap.init with oversize width");
    } else if (height > std.math.maxInt(Pos.Dim)) {
        @panic("FOVMap init with oversize height");
    }

    var i = g.iterator();
    while (i.next()) |t| {
        t.* = .init;
    }

    return .{
        .grid = g,
        .max = .init(@intCast(width - 1), @intCast(height - 1)),
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.grid.deinit(allocator);
}

//
// Utilities
//

fn find(self: *Self, p: Pos) *Tile {
    return self.grid.find(@intCast(p.getX()), @intCast(p.getY())) catch {
        @panic("Bad pos sent to FOVMap.find");
    };
}

//
// Iterator
//

pub const Iterator = struct {
    s: *Self = undefined,
    r: Pos.Range = undefined,

    pub const Item = struct {
        pos: Pos,
        visible: bool,
    };

    pub fn next(self: *Iterator) ?Item {
        if (self.r.next()) |p| {
            return .{ .pos = p, .visible = self.s.find(p).visible };
        }
        return null;
    }

    pub fn next_changed(self: *Iterator) ?Item {
        while (self.r.next()) |p| {
            const t = self.s.find(p);
            if (t.changed) {
                t.changed = false;
                return .{ .pos = p, .visible = self.s.find(p).visible };
            }
        }
        return null;
    }
};

// TODO: changed_iterator with first and last in the grid

pub fn iterator(self: *Self) Self.Iterator {
    return .{
        .s = self,
        .r = Pos.Range.init(.init(0, 0), self.max),
    };
}

//
// Methods
//

pub fn reset(self: *Self) void {
    var i = self.grid.iterator();
    while (i.next()) |tile| {
        tile.* = .init;
    }
}

fn getChanged(self: *Self, p: Pos) bool {
    // Testing utility at least for now
    return self.find(p).changed;
}

pub fn setChanged(self: *Self, p: Pos, changed: bool) void {
    // TODO: first and last changed in the grid
    self.find(p).changed = changed;
}

fn getVisible(self: *Self, p: Pos) bool {
    return self.find(p).visible;
}

pub fn setVisible(self: *Self, p: Pos, visible: bool) void {
    // TODO: first and last visible in the grid
    var tile = self.find(p);
    if (visible != tile.visible) {
        tile.visible = visible;
        tile.changed = true;
    }
}

//
// Unit tests
//
// Invalid positions will panic
//

const expect = std.testing.expect;

test "basic use" {
    var map = try init(std.testing.allocator, 50, 50);
    defer map.deinit(std.testing.allocator);

    try expect(map.getChanged(.init(10, 10)) == false); // Condition of init

    map.setChanged(.init(10, 10), true);
    try expect(map.getChanged(.init(10, 10)) == true);
    map.setChanged(.init(10, 10), false); // Pretend it was sampled

    map.setVisible(.init(10, 10), true);
    try expect(map.getVisible(.init(10, 10)) == true);
    try expect(map.getChanged(.init(10, 10)) == true);

    map.setChanged(.init(10, 10), false); // Pretend this has been reported
    try expect(map.getVisible(.init(10, 10)) == true);

    map.setVisible(.init(10, 10), false);
    try expect(map.getChanged(.init(10, 10)) == true);

    map.setChanged(.init(10, 10), false); // Pretend this has been reported

    map.setVisible(.init(10, 10), false); // No change
    try expect(map.getChanged(.init(10, 10)) == false);

    map.reset();
    try expect(map.getVisible(.init(10, 10)) == false);
    try expect(map.getChanged(.init(10, 10)) == false);
}

test "iterator" {
    var map = try init(std.testing.allocator, 5, 5);
    defer map.deinit(std.testing.allocator);

    var it = map.iterator();
    if (it.next()) |i| {
        try expect(i.pos.getX() == 0);
    } else {
        try expect(false);
    }

    if (it.next()) |i| {
        try expect(i.pos.getX() == 1);
    } else {
        try expect(false);
    }

    while (it.next()) |i| {
        try expect(i.pos.getX() < 5);
        try expect(i.pos.getY() < 5);
    }
}

test "changed iterator" {
    var map = try init(std.testing.allocator, 5, 5);
    defer map.deinit(std.testing.allocator);

    // Created with no changed bits set

    var it = map.iterator();
    if (it.next_changed()) |_| {
        try expect(false);
    }

    map.setChanged(.init(1, 0), true); // Skip index 1

    it = map.iterator();
    if (it.next_changed()) |i| {
        try expect(i.pos.getX() == 1);
    } else {
        try expect(false);
    }

    map.setChanged(.init(4, 4), true);

    while (it.next_changed()) |i| { // Finish the series
        try expect(i.pos.getX() == 4);
        try expect(i.pos.getY() == 4);
    }

    it = map.iterator(); // Changed bits reset, so no more
    try expect(it.next_changed() == null);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
