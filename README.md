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

### None so far; trying to get it to what was 0.2 in the previous iteration

### Forward looking

With a basic engine we can talk about repositioning it for Webassembly or
some clever webservice prop-up (umoria has this and it is awesome) and for
client-server and multiplayer.

I don't care about Windows binaries.

Also need to consider issues around serialization and if Lua integration
makes sense / sounds fun.

Food?  Implies timers, possibly inventory, statuses

# Internal Documentation
  * [Gameplay!](/doc/gameplay.md)
  * [Implementation Details](/doc/implementation.md)
  * [Items](/doc/items.md)
  * [Levels](/doc/levels.md)

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
