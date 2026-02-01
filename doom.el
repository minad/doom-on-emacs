;;; doom.el --- DOOM on Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2012-2026 doomgeneric contributors, Akhsarbek Gozoev, bcoles,
;;   Daniel Bomar, Daniel Mendler, Fabian Ruhland, Georgi Gerganov,
;;   indigoparadox, isif00, lukneu, Maxime Vincent, Ørjan, ozkl, techflashYT,
;;   Travis Bradshaw, Trider12, Turo Lamminen
;; Copyright (C) 1993-1996 Id Software, Inc.

;; Author: Daniel Mendler <mail@daniel-mendler.de>
;; Maintainer: Daniel Mendler <mail@daniel-mendler.de>
;; Created: 2026
;; Version: 0.1
;; Package-Requires: ((emacs "31.0"))
;; URL: https://github.com/minad/doom-on-emacs
;; Keywords: games

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This is DOOM running inside Emacs to test the Canvas API.

;;; Code:

(defvar doom-refresh-timer nil
  "Refresh timer.")

(defvar doom-canvas nil
  "Drawing canvas.")

(defvar doom-start-ms 0
  "Start time in milliseconds.")

(defvar doom-keys nil
  "List of key events.")

(defvar doom-last-key nil
  "Last key press.")

(defvar doom-key-up-timer nil
  "Timer to simulate key up event.")

(defvar doom-frame-rate 35
  "Refreshing frame rate.")

;; TODO: Smoothing is slow in Emacs except if we use CAIRO_FILTER_GOOD in
;; image.c or Xrender. See Emacs bug#79204 or
;; https://lists.gnu.org/r/emacs-devel/2025-07/msg00475.html.
(defvar doom-smooth nil
  "Smooth scaling.")

(defvar doom-buffer "*doom*"
  "Buffer name.")

(defvar doom-frame-count 0
  "Frame count.")

(defvar doom-frame-time nil
  "Frame count start time.")

(defvar doom-mode-line-frame-rate nil
  "Measured frame rate in mode line.")

(defvar doom-mode-line-title nil
  "Window title in mode line.")

(declare-function doom-tick "ext:doomgeneric_emacs.c")

(defun doom-ms ()
  "Milliseconds since start."
  (pcase-let ((`(,hi ,lo ,us ,_) (current-time)))
    (- (+ (* 1000 (logior (ash hi 16) lo)) (/ us 1000)) doom-start-ms)))

(defun doom-title (title)
  "Set TITLE."
  (setq doom-mode-line-title title))

(defun doom-canvas ()
  "Get canvas or stop timer if buffer is closed."
  (if-let* ((buffer (get-buffer doom-buffer)))
      (when-let* ((win (get-buffer-window buffer))
                  (time (float-time))
                  (delta (- time doom-frame-time)))
        (incf doom-frame-count)
        (when (> delta 2)
          (setq doom-mode-line-frame-rate (format " FPS: %.1f" (/ doom-frame-count delta))
                doom-frame-time time
                doom-frame-count 0)
          (force-mode-line-update t))
        (let* ((scale (plist-get (cdr doom-canvas) :scale))
               (ww (window-text-width win t))
               (wh (window-text-height win t))
               (nscale (min (/ ww 320.0) (/ wh 200.0))))
          (when (/= scale nscale)
            (image-flush doom-canvas)
            (plist-put (cdr doom-canvas) :margin
                       (cons (/ (- ww (round (* 320 nscale))) 2)
                             (/ (- wh (round (* 200 nscale))) 2)))
            (plist-put (cdr doom-canvas) :scale nscale)))
        doom-canvas)
    (cancel-timer doom-refresh-timer)
    (setq doom-refresh-timer nil)))

(defun doom-key-down (key)
  "Simulate KEY press."
  ;; (message "DOWN %S" key)
  (setq doom-keys `(,@doom-keys ,@(mapcar (lambda (k) (logior k #x100)) key))
        doom-last-key key))

(defun doom-key-up ()
  "Simulate release of last key."
  (when doom-last-key
    ;; (message "UP %S" doom-last)
    (setq doom-keys `(,@doom-keys ,@doom-last-key)
          doom-last-key nil)))

(defun doom-key ()
  "Get last key or 0."
  (or (pop doom-keys) 0))

(defun doom-key-command (key &optional name)
  "Command which pushes KEY to the queue.
NAME is an optional readable name."
  (let ((sym (intern
              (format "doom-key:%s"
                      (or name (downcase (key-description (vector key)))))))
        (key (ensure-list key)))
    (defalias sym
      (lambda ()
        (interactive nil doom-mode)
        (unless (equal key doom-last-key)
          (doom-key-up)
          (doom-key-down key))
        (when doom-key-up-timer
          (cancel-timer doom-key-up-timer)
          (setq doom-key-up-timer nil))
        ;; HACK: We simulate key up events with a timer.  Use low level key events
        ;; as soon as bug#74423 lands in Emacs.
        (setq doom-key-up-timer (run-at-time 0.05 nil
                                             (lambda ()
                                               (doom-key-up)
                                               (setq doom-key-up-timer nil)))))
      (format "Send key %s to DOOM." name))
    sym))

(defvar-keymap doom-mode-map
  :doc "Keymap used by `doom-mode'."
  "<right>"    (doom-key-command #xae 'right)
  "<left>"     (doom-key-command #xac 'left)
  "<down>"     (doom-key-command #xaf 'down)
  "<up>"       (doom-key-command #xad 'up)
  "S-<left>"   (doom-key-command '(#xb6 #xa0) 'fast-strafe-l)
  "S-<right>"  (doom-key-command '(#xb6 #xa1) 'fast-strafe-r)
  "S-<down>"   (doom-key-command '(#xb6 #xaf) 'fast-down)
  "S-<up>"     (doom-key-command '(#xb6 #xad) 'fast-up)
  "C-<left>"   (doom-key-command #xa0 'strafe-l)
  "C-<right>"  (doom-key-command #xa1 'strafe-r)
  "C-<down>"   (doom-key-command #xaf 'down)
  "C-<up>"     (doom-key-command #xad 'up)
  "M-<left>"   (doom-key-command #xa0 'strafe-l)
  "M-<right>"  (doom-key-command #xa1 'strafe-r)
  "M-<down>"   (doom-key-command #xaf 'down)
  "M-<up>"     (doom-key-command #xad 'up)
  ;; Blocks cheats like idkfa
  ;; "w" (doom-key-command #xad 'up)
  ;; "a" (doom-key-command #xa0 'strafe-l)
  ;; "s" (doom-key-command #xaf 'down)
  ;; "d" (doom-key-command #xa1 'strafe-r)
  "C-SPC"      (doom-key-command #xa3 'fire)
  "M-SPC"      (doom-key-command #xa3 'fire)
  "SPC"        (doom-key-command #xa3 'fire)
  "S-SPC"      (doom-key-command #xa3 'fire)
  "C-<return>" (doom-key-command #xa2 'use)
  "M-<return>" (doom-key-command #xa2 'use)
  "S-<return>" (doom-key-command #xa2 'use)
  ","          (doom-key-command #xa0 'strafe-l)
  "."          (doom-key-command #xa1 'strafe-r)
  "<escape>"   (doom-key-command ?\e)
  "RET"        (doom-key-command ?\r)
  "TAB"        (doom-key-command ?\t))

(let ((k ?!))
  (while (< k 128)
    (unless (lookup-key doom-mode-map (vector k))
      (define-key doom-mode-map (vector k) (doom-key-command k)))
    (incf k)))

(defun doom--barf-write ()
  "Barf for write operation."
  (set-buffer-modified-p nil)
  (setq buffer-read-only t)
  (set-visited-file-name nil)
  (error "Writing the buffer to a file is not supported"))

(defun doom--barf-change-mode ()
  "Barf for change mode operation."
  (error "Changing the major mode is not supported"))

(define-derived-mode doom-mode special-mode "DOOM"
  "DOOM mode."
  :interactive nil :abbrev-table nil :syntax-table nil
  (setq-local buffer-read-only t
              cursor-type nil
              eldoc-documentation-functions nil
              fringe-indicator-alist '((truncation . nil))
              left-fringe-width 1
              right-fringe-width 1
              left-margin-width 0
              right-margin-width 0
              truncate-lines t
              show-trailing-whitespace nil
              display-line-numbers nil
              default-directory (expand-file-name "~/")
              mode-line-process '((doom-mode-line-title " Title: ")
                                  (doom-mode-line-title doom-mode-line-title)
                                  (doom-mode-line-frame-rate doom-mode-line-frame-rate))
              mode-line-position nil
              mode-line-modified nil
              mode-line-mule-info nil
              mode-line-remote nil
              face-remapping-alist
              '((default (:background "black" :foreground "white") default)))
  (add-hook 'change-major-mode-hook #'doom--barf-change-mode nil 'local)
  (add-hook 'write-contents-functions #'doom--barf-write nil 'local))

(defun doom ()
  "Run DOOM."
  (interactive)
  (unless (image-type-available-p 'canvas)
    (error "Canvas API is not available"))
  (unless doom-canvas
    (setq doom-canvas `(image :type canvas
                              :scale 1.0
                              :margin (0 . 0)
                              :transform-smoothing ,doom-smooth
                              :canvas-id doom
                              :canvas-width 320
                              :canvas-height 200)
          doom-start-ms (doom-ms)
          doom-frame-time (float-time)))
  (with-current-buffer (get-buffer-create doom-buffer)
    (with-silent-modifications
      (doom-mode)
      (erase-buffer)
      (insert (propertize "#" 'display doom-canvas))))
  (unless (fboundp #'doom-tick)
    (let* ((default-directory
            (or (locate-file "doomgeneric"
                             (cons nil load-path) nil
                             (lambda (f) (and (file-directory-p f) 'dir-ok)))
                (error "Source directory `doomgeneric' not found")))
           (mod (expand-file-name
                 (file-name-with-extension
                  "doomgeneric_emacs" module-file-suffix))))
      (unless (file-exists-p mod)
        (with-current-buffer (get-buffer-create "*doom-compile*")
          (compilation-mode)
          (switch-to-buffer (current-buffer))
          (with-silent-modifications
            (call-process "make" nil t t "-fMakefile.emacs"
                          (format "-j%d" (num-processors))))))
      (module-load mod)))
  (unless doom-refresh-timer
    (setq doom-refresh-timer (run-at-time nil (/ 1.0 doom-frame-rate) #'doom-tick)))
  (switch-to-buffer doom-buffer)
  (message "%s" (substitute-command-keys
                 "DOOM: Press \\[describe-mode] to see the key bindings")))

(provide 'doom)
;;; doom.el ends here
