;; ========================
;; evil and its eco system
;; ========================

;; the key will no longer work after this file was reloaded, so
;; it must only be set once
(if (not (bound-and-true-p global-evil-leader-mode))
    (evil-leader/set-leader "<SPC>"))

(global-evil-leader-mode 1)
(evil-mode 1)
(global-evil-surround-mode 1)


;; not needed with aggresive-indent-mode
(setq evil-auto-indent 0)

;; shift width via <>
(setq evil-shift-width 4)

;; repeating with . will not move the cursor
(setq evil-repeat-move-cursor 0)

;; character search will skip newlines
(setq evil-find-skip-newlines t)

(define-key evil-normal-state-map (kbd "C-a") 'evil-beginning-of-line)
(define-key evil-insert-state-map (kbd "C-a") 'evil-beginning-of-line)
(define-key evil-visual-state-map (kbd "C-a") 'evil-beginning-of-line)
(define-key evil-operator-state-map (kbd "C-a") 'evil-beginning-of-line)

(define-key evil-normal-state-map (kbd "C-e") 'evil-end-of-line)
(define-key evil-insert-state-map (kbd "C-e") 'end-of-line)
(define-key evil-visual-state-map (kbd "C-e") 'evil-end-of-line)
(define-key evil-operator-state-map (kbd "C-e") 'evil-end-of-line)

(define-key evil-insert-state-map (kbd "C-<SPC>") 'company-complete)

(define-key evil-normal-state-map (kbd "C-x C-x") 'evil-goto-mark)
(define-key evil-insert-state-map (kbd "C-x C-x") 'evil-goto-mark)

(define-key evil-normal-state-map (kbd "C-p") 'helm-show-kill-ring)

(define-key evil-normal-state-map (kbd "C-s") 'isearch-forward)
(define-key evil-normal-state-map (kbd "C-r") 'isearch-backward)

(define-key evil-normal-state-map (kbd "f") 'ace-jump-char-mode)
(define-key evil-normal-state-map (kbd "F") 'ace-jump-word-mode)

(evil-leader/set-key
  "f s" 'save-buffer
  "f o" 'helm-find-files
  "f S" 'save-some-buffers
  "f e" 'eval-buffer
  "f k" 'kill-buffer
  "H H" 'helm-apropos
  "g s" 'magit-status
  "l"   'helm-mini
  "i"   'helm-semantic-or-imenu
  "M"   'helm-man-woman
  "C-o" 'helm-occur
  "C-r" 'helm-resume
  "0"   'delete-window
  "o"   'ace-window
  "1"   'delete-other-windows
  "2"   'split-window-vertically
  "3"   'split-window-horizontally
  "r"   'query-replace-regexp
  "+"   'set-mark-command
  "j"   'ace-jump-line-mode)

(defun aggressive-indent-if ()
  (unless (member (buffer-local-value 'major-mode (current-buffer)) '(python-mode org-mode))
    (aggressive-indent-mode 1)))

;; evil state hooks
(add-hook 'evil-normal-state-entry-hook
          '(lambda ()
             (set-face-background 'powerline-active1 "#ab3737")
             (set-face-background 'mode-line "#6b95b2")
             (aggressive-indent-mode 0)
             (powerline-reset)))

(add-hook 'evil-emacs-state-entry-hook
          '(lambda ()
             (set-face-background 'powerline-active1 "#2f2f2f")
             (set-face-background 'mode-line "#6b95b2")
             (aggressive-indent-if)
             (powerline-reset)))

(add-hook 'evil-visual-state-entry-hook
          '(lambda ()
             (set-face-background 'powerline-active1 "#79596d")
             (set-face-background 'mode-line "#6b95b2")
             (aggressive-indent-mode 0)
             (powerline-reset)))

(add-hook 'evil-insert-state-entry-hook
          '(lambda ()
             (set-face-background 'powerline-active1 "#3d6837")
             (set-face-background 'mode-line "#6b95b2")
             (aggressive-indent-if)
             (powerline-reset)))

