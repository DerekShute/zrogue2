//!
//! Player action handler, here at least for now
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Entity = @import("roguelib").Entity;
const Feature = @import("roguelib").Feature;
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;
const Tileset = @import("roguelib").Tileset;
const features = @import("features.zig");

//
// Types
//

// Function call prototype

const Handler = *const fn (self: *Entity, action: *Action, map: *Map) Action.Result;

//
// Action service
//

pub fn doAction(entity: *Entity, map: *Map) Action.Result {
    var action = entity.getAction();
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

    const ret = actFn(entity, &action, map);
    return ret;
}

//
// Handlers
//

fn doNothing(entity: *Entity, action: *Action, map: *Map) Action.Result {
    _ = entity;
    _ = action;
    _ = map;

    return .continue_game;
}

fn doAscend(entity: *Entity, action: *Action, map: *Map) Action.Result {
    _ = action;
    if (map.getFloorTile(entity.getPos()) == .stairs_up) {
        entity.addMessage("You ascend closer to the exit..."); // TODO stupid
        return .ascend;
    }
    entity.addMessage("I see no way up");
    return .continue_game;
}

fn doDescend(entity: *Entity, action: *Action, map: *Map) Action.Result {
    _ = action;
    if (map.getFloorTile(entity.getPos()) == .stairs_down) {
        entity.addMessage("You go ever deeper into the dungeon...");
        return .descend;
    }

    entity.addMessage("I see no way down");
    return .continue_game;
}

fn doMove(entity: *Entity, action: *Action, map: *Map) Action.Result {
    const old_pos = entity.getPos();
    const new_pos = Pos.add(old_pos, action.getPos());

    if (map.passable(new_pos)) {
        map.removeEntity(old_pos);
        entity.setPos(new_pos);
        map.addEntity(entity, new_pos);
        entity.revealMap(map, old_pos);
        _ = features.enter(entity, map, new_pos);
    } else {
        entity.addMessage("Ouch!"); // Future: 'bump' callback
    }

    return .continue_game;
}

fn doQuit(entity: *Entity, action: *Action, map: *Map) Action.Result {
    _ = entity;
    _ = action;
    _ = map;
    // TODO: save, ask, etc.
    return .end_game;
}

fn doSearch(entity: *Entity, action: *Action, map: *Map) Action.Result {
    _ = action;

    var r = Region.configRadius(entity.getPos(), 1);
    var i = r.iterator();
    var found: bool = false;
    while (i.next()) |pos| {
        found |= features.find(entity, map, pos); // aggregate result
    }

    if (found) {
        entity.addMessage("You find something!");
    } else {
        entity.addMessage("You find nothing!");
    }

    return .continue_game;
}

fn doTake(entity: *Entity, action: *Action, map: *Map) Action.Result {
    const p = action.getPos();
    const i = map.getItem(p);
    if (i == .unknown) {
        entity.addMessage("Nothing here to take!");
    } else {
        map.removeItem(p);
        entity.takeItem(i);
    }
    return .continue_game;
}

// EOF
