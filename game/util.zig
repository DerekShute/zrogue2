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
    const old_pos = player.getPos();
    const new_pos = Pos.add(old_pos, action.getPos());

    if (map.passable(new_pos)) {
        map.removeEntity(old_pos);
        player.setPos(new_pos);
        map.addEntity(player.getEntity(), new_pos);
        player.revealMap(map, old_pos);

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
