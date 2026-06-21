# Learning Zig the hard way (again) by porting Rogue (again)

Zig 0.15 hit the original attempt like a sack of potatoes.  So, I took it as
an opportunity to start over, reworking the pieces that were not exactly in
the canonical Zig style.  The easiest way to do that was to start over.

## Goals

Proficiency in Ziglang, which is turning out to be an interesting journey.

This may never beome a finished product; if I learn as much as this exercise
will teach me then it will very readily get kicked to the curb.

The goal is not a 1:1 replication of the original, which intertwines the
interface with the behavioral logic and assumes a single-player environment,
possibly in the name of efficiency.

I really want this to be the basis of something more flexible, separating
the front-end (interface) from the game logic and arbitration (engine),
allowing multiple implementations and even possibly a multi-user experience.

And part of this is figuring out why certain things about the original
implementation are the way they are--why is THING (literally) a union mashing
together monster and object/gear characteristics?

   (spoiler: I think it was so that the list management is consolidated)

## Reference points

"Canonical" Rogue behavior given by:

   https://github.com/Davidslv/rogue/

And my own feeble Python effort:

   https://github.com/DerekShute/PyRogue/

Which started from the very instructive v2 TCOD tutorial:

   https://rogueliketutorials.com/tutorials/tcod/v2/

## Releases

Make this game hang together better.  Truly multiplayer, and a real RESTful
interface that advertises itself properly and does some kind of WebSocket for
game transactions after authentication.  And authentication because people
seem to think that is important.

### 0.5 (roadmap)

Smash the Game abstraction and a library-level World throughout the mechanism,
invading mapgen and actions and so forth.  Game or World owns prng and a
friendlier randomization interface (with mock)

Rewrite FOV yet again so that the sum of them can be traversed.  A player moves
and all who have that spot visible receive an update.

Possibly invent a command-completion-reply that would stabilize the client
interface.  Maybe a half-blocking ncurses interface, though that may not be
portable.

Interactions and broadcasts and notifications

Multiple multiplayer maps

### 0.4 primitive multiplayer

The server is multithreaded and accepts multiple connections, depositing
players into a shared map (do not attempt to use the stairs)

Players can see each other, but movement does not percolate to the FOV of
everyone involved.  Collisions are detected on the actor side

Disconnection is crude but seems stable.

There's a beginning "Game" structure concept which needs to thread throughout
and probably be a Game versus World in the library.

### 0.3 client and server

Bad client and server

One client, one server.  Basically the single player version played the least
efficient way possible.  Nothing is propped up in a friendly way and nothing
about this is resilent or multiplayer.  But as long as the protocol remains
stable (spoiler: it won't) there is enough on that side to make material
improvements to the server.

The network protocol stands on top of MessagePack--the options for general
map updates using JSON appear limited--and TCP.  There is admittedly a lot of
layers and abstraction going on.

Still not in the mood to improve the actual game itself or refine the
interface.

### 0.3 client-server

Split the pieces apart that the client and server play one single threaded
single user game.  This is not exactly a victory.

### 0.2 prepped for whatever is next

linux-cli/ encapsulates the single-user linux CLI version, and interactions
have been contained to the point where I can turn this client-server.

### 0.1 basic basic stuff

Three dungeon levels with gold, dark rooms, secret doors, and traps

### Principles

I don't care about Windows binaries.

Also need to consider issues around serialization and if Lua integration
makes sense / sounds fun.

Food?  Implies timers, possibly inventory, statuses

# Internal Documentation
  * [Gameplay!](/doc/gameplay.md)
  * [Implementation Details](/doc/implementation.md)
  * [Items](/doc/items.md)
  * [Levels](/doc/levels.md)
  * [Protocol](/doc/protocol.md)

# What, you want to use this?

Color me shocked!  Shocked and flattered!

I'm only interested in it running from Ubuntu 24.04 and this only from PuTTY
from Windows, because that's my admittedly primitive/awful operating
environment.  Other use might run into keypress-translation issues and ncurses
support.

### Building on Ubuntu 24.04, which is my workflow

  cat requirements.ubuntu-24.04 | xargs sudo apt install

  (without gcc and g++ then there is a problem finding the tinfo library, necessary for ncurses)

### Emacs yes I'm one of those and these notes are for _me_ thank you

https://github.com/ziglang/zig-mode
https://github.com/purcell/emacs-reformatter

checked out into ~/.emacs.d

and .emacs looks approximately like this
```
(add-to-list 'load-path "~/.emacs.d/emacs-reformatter/")
(add-to-list 'load-path "~/.emacs.d/zig-mode/")
(autoload 'zig-mode "zig-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.\\(zig\\|zon\\)\\'" . zig-mode))
```

zig-mode gives a test against emacs 24 but Ubuntu 24.04 delivers version 29
