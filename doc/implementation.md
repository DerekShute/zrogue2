## Layout

A work in progress.  There is:

* roguelib : generic map-and-mechanics
  * protocol : the messaging protocol messages and test apparatus
* doc : you are here
* game : the game that would be implemented, that wields the mapgen and
  roguelib
* src : source directory of various programs
  * fuzz : fuzz/error testing for server
  * linux-client : client side of server
  * linux-server : server side
  * linux-zrogue : single-player game version
  * testing : apparatus
* ui : chum bucket for user interface
  * NCurses : low-level ncurses utilities (a separate module)
  * Rogue : Rogue presentation layer for ncurses
    * keypress interpretation
    * element positioning and reporting

## Modules

### game

The game, in whatever form it currently exists

### roguelib

The most generally-useful things I can think of.  Positions, maps of tiles,
Entities, and so forth.  These are the substrate.

### ui (rogueui, for lack of better)

Chum bucket of ui elements, from the ncurses low-level utilities to the presentation layer for rogue that
sits on that (and is used by both the standalone and the network client)

## Test scaffolding

Zig is amazing in this regard and I'm trying to work a top-level testing
directory that approaches it holistically, with all knowledge of all modules.
That way the unit tests in each subdir can be specific.

The goal is that each subsection, each element can be unit tested for
correctness.  Bugfixes should be boiled down to unit test validation.

## Code Coverage

I'll need to revisit this when kcov works with 26.04 or reliably in the GitHub
workflow.

I personally consider code coverage to be a pillar of testing strategy and
have used it elsewhere to really crush out bugs.

## Doc generation

Clearly a work in progress for Zig 0.15.  I will try for due diligence.

## Visualization

Generates zig-out/visual.svg, which is a directed graph showing relationships
between structures in the roguelib subdir.  This is done by amazing comptime
magic threaded through some gross Python logic to hammer it into something
vaguely YAML-shaped.

Invoked by the Makefile, the visual target.

When I feel inspired, I'll do something to hook it into the documentation.

## Network Protocol

Sits on top of Messagepack, because that seemed like a good idea at the time.
Message receipt is always done into a very limited allocator to prevent
malfeasance through some data bomb.  If it doesn't fit into 300 bytes then we
don't want it or whoever sent it.
