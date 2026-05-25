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
const features = @import("features.zig");

//
// Types
//

// Function call prototype

const Handler = *const fn (self: *Entity, action: *Action, map: *Map) Action.Result;

//
// Action service
//

pub fn doAction(entity: *Entity, map: *Map) !Action.Result {
    var action = try entity.getAction();
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
    const new_pos = Pos.add(entity.getPos(), action.getPos());

    if (!map.passable(new_pos)) {
        entity.addMessage("Ouch!"); // FUTURE: 'bump' callback
        return .continue_game;
    }

    moveEntity(entity, map, new_pos);

    return .continue_game;
}

fn doQuit(entity: *Entity, action: *Action, map: *Map) Action.Result {
    _ = entity;
    _ = action;
    _ = map;
    // FUTURE: save, ask, etc.
    return .end_game;
}

fn doSearch(entity: *Entity, action: *Action, map: *Map) Action.Result {
    _ = action;

    var r = Region.configRadius(entity.getPos(), 1);
    var i = r.iterator();
    var found: bool = false;
    while (i.next()) |pos| {
        if (map.getFeature(pos)) |f| {
            found |= f.find(entity, map, pos); // aggregate result
        }
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

//
// Utilities
//

// Move the entity to a new position in the map
//
// (Might be assuming adjacent to old)
//
pub fn moveEntity(entity: *Entity, map: *Map, new_pos: Pos) void {
    const old_pos = entity.getPos();

    // FUTURE: feature trigger to leave position

    map.removeEntity(old_pos);
    entity.setPos(new_pos);
    map.addEntity(entity, new_pos);

    const new_floor = map.getFloorTile(new_pos);
    const old_floor = map.getFloorTile(old_pos);
    const new_lit = map.isLit(new_pos);
    const old_lit = map.isLit(old_pos);

    // This sort of how urogue manages it: room floor and corridors are
    // different tiles and movement between will light and extinguish the
    // room

    if ((old_floor == .door) and (new_floor == .floor)) {
        // Into the room properly
        entity.setRegionVisible(.configRadius(old_pos, 1), false);
    } else if ((new_floor == .door) and (old_floor == .corridor)) {
        // Into threshold
        entity.setRegionVisible(.configRadius(old_pos, 1), false);
        enterRoom(entity, map);
    } else if ((new_floor == .corridor) and (old_floor == .door)) {
        // Leaving threshold and into dark corridor
        leaveRoom(entity, map, old_pos);
    } else if (!new_lit and !old_lit) {
        // Moving around in a corridor or a dark room
        entity.setRegionVisible(.configRadius(old_pos, 1), false);
    }
    entity.setRegionVisible(.configRadius(new_pos, 1), true);

    _ = map.enterFeature(entity, new_pos);

    entity.notifyDisplay(map);
}

// Enter a room

pub fn enterRoom(entity: *Entity, map: *Map) void {
    if (map.isLit(entity.getPos())) {
        // Entering a lit room : update what is now visible
        if (map.getRoomRegion(entity.getPos())) |region| {
            entity.setRegionVisible(region, true);
        }
    }

    // FUTURE: triggers for monsters, etc.
}

// Leave a room

pub fn leaveRoom(entity: *Entity, map: *Map, old_pos: Pos) void {
    if (map.isLit(old_pos)) {
        // Leaving a lit room : update what is now visible
        if (map.getRoomRegion(old_pos)) |region| {
            entity.setRegionVisible(region, false);
        }
    }

    // FUTURE: triggers for monsters, etc.
}

// EOF
