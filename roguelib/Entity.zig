//!
//! Abstraction structure for monsters and player
//!

const std = @import("std");

const Action = @import("Action.zig");
const DisplayTile = @import("common").DisplayTile;
const FOVMap = @import("FOVMap.zig");
const Map = @import("Map.zig");
const Pos = @import("Pos.zig");
const queue = @import("queue.zig");
const Region = @import("Region.zig");
const Tile = @import("common").Tile;

const Self = @This();

//
// Types
//

pub const Queue = queue.Queue(Self, "node");

pub const VTable = struct {
    pub const Error = error{Failed};

    addMessage: ?*const fn (self: *Self, msg: []const u8) void = null,
    getAction: ?*const fn (self: *Self) Error!Action = null,
    setMapTile: ?*const fn (self: *Self, pos: Pos, count: u8, tile: DisplayTile) void = null,
    takeItem: ?*const fn (self: *Self, map: *Map, pos: Pos) void = null,
};

pub const Config = struct {
    tile: Tile,
    vtable: *const VTable,
};

//
// Members
//

// FUTURE: timer, action queue
p: Pos = undefined,
tile: Tile = undefined,
vtable: *const VTable = undefined,
moves: i32 = 0,
node: queue.Node = .{},
fov: ?*FOVMap = null,

//
// Lifecycle
//

pub fn init(config: Config) Self {
    return .{
        .p = .init(-1, -1),
        .tile = config.tile,
        .vtable = config.vtable,
    };
}

pub fn setFOV(self: *Self, fov: *FOVMap) void {
    self.fov = fov;
}

//
// Methods
//

pub fn getTile(self: *Self) Tile {
    return self.tile;
}

pub fn getPos(self: *Self) Pos {
    return self.p;
}

pub fn setPos(self: *Self, p: Pos) void {
    if (self.p.getX() != -1) {
        self.setPosChanged(self.p);
    }
    self.p = p;
    self.setPosChanged(p);
}

pub fn getMoves(self: *Self) i32 {
    return self.moves;
}

// VTable

pub fn addMessage(self: *Self, msg: []const u8) void {
    if (self.vtable.addMessage) |cb| {
        cb(self, msg);
    }
}

pub fn getAction(self: *Self) !Action {
    if (self.vtable.getAction) |cb| {
        return try cb(self);
    }
    return Action.config(.none);
}

pub fn takeItem(self: *Self, map: *Map, pos: Pos) void {
    if (self.vtable.takeItem) |cb| {
        cb(self, map, pos);
    }
}

// Field of Vision

pub fn setPosChanged(self: *Self, loc: Pos) void {
    if (self.fov) |fov| {
        fov.setChanged(loc, true);
    }
}

pub fn setPosVisible(self: *Self, loc: Pos, visible: bool) void {
    if (self.fov) |fov| {
        fov.setVisible(loc, visible);
    }
}

pub fn setRegionVisible(self: *Self, region: Region, visible: bool) void {
    var _r = region; // Flip to var
    if (self.fov) |fov| {
        var ri = _r.iterator();
        while (ri.next()) |p| {
            fov.setVisible(p, visible);
        }
    }
}

//
// It's up to the client and end UI to decide what to do with map areas that
// are no longer visible.  It could remove them from the display, or dim them,
// or only retain known-persistent features.
//
// This could be done piecemeal but that reduces opportunity for consolidation
//
// TODO: still not really cool with this
//
// FUTURE: slice of DisplayTile
//
pub fn notifyDisplay(self: *Self, map: *Map) void {
    var dt: DisplayTile = undefined;
    var pos: Pos = undefined;
    var count: u8 = 0;

    if ((self.vtable.setMapTile == null) or (self.fov == null)) {
        return;
    }
    const smt = self.vtable.setMapTile.?;
    const fov = self.fov.?;

    var i = fov.iterator();
    while (i.next_changed()) |change| {
        if (count == 0) {
            pos = change.pos;
            count = 1;
            dt = .init;
            if (change.visible) {
                const tile = map.getTileset(change.pos);
                dt = DisplayTile{
                    .entity = @intFromEnum(tile.entity),
                    .floor = @intFromEnum(tile.floor),
                    .item = @intFromEnum(tile.item),
                    .visible = true,
                };
            }
            continue;
        }
        // One in the tank; can it be combined?

        const tile = map.getTileset(change.pos);
        if ((change.pos.getY() == pos.getY()) and
            (change.pos.getX() == pos.getX() + count))
        {
            if (!change.visible and !dt.visible) {
                // Equally invisible; can combine
                count = count + 1;
                continue;
            }

            if ((change.visible == dt.visible) and // implies both visible
                (dt.entity == @intFromEnum(tile.entity)) and
                (dt.floor == @intFromEnum(tile.floor)) and
                (dt.item == @intFromEnum(tile.item)))
            {
                // The same and both visible; combine
                count = count + 1;
                continue;
            }
        }

        // Can't graft it, so flush the existing and keep going
        smt(self, pos, count, dt);
        pos = change.pos;
        count = 1;
        dt = .init;
        if (change.visible) {
            dt = DisplayTile{
                .entity = @intFromEnum(tile.entity),
                .floor = @intFromEnum(tile.floor),
                .item = @intFromEnum(tile.item),
                .visible = true,
            };
        }
    } // While
    if (count > 0) {
        // Flush anything trailing
        smt(self, pos, count, dt);
    }
}

//
// Unit Tests
//

const expect = std.testing.expect;

test "entity queue" {
    var eq = Queue.config();
    var vt: VTable = .{};

    // TODO: this is kind of a problem.  The FOVMap is glued to this context

    var fov = try FOVMap.init(std.testing.allocator, 100, 100);
    defer fov.deinit(std.testing.allocator);

    const config = Config{
        .tile = @enumFromInt(4),
        .vtable = &vt,
    };
    var e = Self.init(config);

    e.setFOV(&fov);
    try expect(@intFromEnum(e.getTile()) == 4);

    eq.enqueue(&e);
    try expect(eq.next() == &e);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
