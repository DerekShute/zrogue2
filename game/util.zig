//!
//! Player action handler, here at least for now
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Feature = @import("roguelib").Feature;
const Map = @import("roguelib").Map;
const Player = @import("Player.zig");
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;
const Tileset = @import("roguelib").Tileset;
const features = @import("features.zig");

//
// Types
//

// Function call prototype

const Handler = *const fn (self: *Player, action: *Action, map: *Map) Action.Result;

//
// Action service
//

pub fn doPlayerAction(player: *Player, action: *Action, map: *Map) Action.Result {
    const actFn: Handler = switch (action.getType()) {
        .ascend => doAscend,
        .descend => doDescend,
        .move => doMove,
        .take => doTake,
        .quit => doQuit,
        .search => doSearch,
        .none => doNothing,
        .wait => doNothing, // TODO untrue
    };

    return actFn(player, action, map);
}

fn renderTile(player: *Player, map: *Map, pos: Pos, visible: bool) void {
    // TODO: SetKnown(ts, visible), let Provider work it out, including what
    // to do with things that are not currently visible

    const ts = map.getTileset(pos);
    if (visible) {
        if (ts.entity != .unknown) {
            player.setTileKnown(pos, ts.entity);
        } else if (ts.item != .unknown) {
            player.setTileKnown(pos, ts.item);
        } else {
            player.setTileKnown(pos, ts.floor);
        }
    } else {
        if (!ts.floor.isFeature()) {
            player.setTileKnown(pos, .unknown);
        } // else no update: you know it or you don't
    }
}

fn renderRegion(player: *Player, map: *Map, r: Region, visible: bool) void {
    var _r = r; // ditch const
    var ri = _r.iterator();
    while (ri.next()) |p| {
        renderTile(player, map, p, visible);
    }
}

// Pub for initial player placement on map
pub fn revealMap(player: *Player, map: *Map, pos: Pos) void {
    const at_loc = pos.eql(player.getPos()); // prior to new location

    if (map.getRoomRegion(pos)) |r| { // In a room
        const visible = at_loc and map.isLit(pos);
        renderRegion(player, map, r, visible);
    }

    // At doorway, dark room, hallway, need union
    const region = Region.configRadius(pos, 1);
    renderRegion(player, map, region, at_loc);
}

//
// Handlers
//

fn doNothing(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = player;
    _ = action;
    _ = map;

    return .continue_game;
}

fn doAscend(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;
    if (map.getFloorTile(player.getPos()) == .stairs_up) {
        player.addMessage("You ascend closer to the exit..."); // TODO stupid
        return .ascend;
    }
    player.addMessage("I see no way up");
    return .continue_game;
}

fn doDescend(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;
    if (map.getFloorTile(player.getPos()) == .stairs_down) {
        player.addMessage("You go ever deeper into the dungeon...");
        return .descend;
    }

    player.addMessage("I see no way down");
    return .continue_game;
}

// TODO: initial map placement on level
fn doMove(player: *Player, action: *Action, map: *Map) Action.Result {
    const pos = player.getPos();
    const new_pos = Pos.add(pos, action.getPos());

    if (map.passable(new_pos)) {
        map.removeEntity(pos);
        player.setPos(new_pos);

        // TODO: one revealMap() that takes everything into account
        revealMap(player, map, pos);
        map.addEntity(player.getEntity(), new_pos);
        revealMap(player, map, new_pos);

        const f = map.getFeature(new_pos); // TODO wrap
        if (f != .none) {
            _ = features.enter(f, map, new_pos, player);
        }
    } else {
        player.addMessage("Ouch!"); // Future: 'bump' callback
    }

    return .continue_game;
}

fn doQuit(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = player;
    _ = action;
    _ = map;
    // TODO: save, ask, etc.
    return .end_game;
}

fn doSearch(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;

    var r = Region.configRadius(player.getPos(), 1);
    var i = r.iterator();
    var found: bool = false;
    while (i.next()) |pos| {
        const f = map.getFeature(pos);
        if (f != .none) {
            found |= features.find(f, map, pos, player); // aggregate result
        }
    }

    if (found) {
        player.addMessage("You find something!");
    } else {
        player.addMessage("You find nothing!");
    }

    return .continue_game;
}

fn doTake(player: *Player, action: *Action, map: *Map) Action.Result {
    const p = action.getPos();
    const i = map.getItem(p);
    map.removeItem(p);
    player.takeItem(i);
    return .continue_game;
}

// EOF
