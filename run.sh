#!/bin/bash
emacs -batch -f batch-byte-compile doom.el && emacs -Q -l doom.elc -e doom
