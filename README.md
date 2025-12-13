
++ Emacs yes I'm one of those and these notes are for _me_ thank you

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

++ Building on Ubuntu 24.04

  cat requirements.ubuntu-24.04 | xargs sudo apt install

  (without gcc and g++ then there is a problem finding the tinfo library)
