;;; shell-cfg.el --- emacs shell configuration

;;; Commentary:
;;; Code:

(add-hook
 'term-mode-hook
 '(lambda ()
    (setq-local truncate-lines t)
    (setq-local truncate-partial-width-windows nil)
    (setq-local company-backends '())
    (setq-local scroll-margin 0)
    (yas-minor-mode 0))
 t)

(global-set-key [f1] 'multi-term-dedicated-toggle)

(with-eval-after-load "term"

  (evil-set-initial-state 'term-mode 'emacs)

  (define-key term-raw-map  (kbd "<escape>") 'term-send-raw)
  (define-key term-mode-map (kbd "<escape>") 'term-send-raw)
  (define-key term-raw-map (kbd "C-^") 'evil-buffer)
  (define-key term-raw-map (kbd "M-l") 'term-send-forward-word)
  (define-key term-raw-map (kbd "M-h") 'term-send-backward-word)
  (define-key term-raw-map (kbd "M-<backspace>") 'term-send-backward-kill-word)

  (setq-default
   multi-term-buffer-name                           "Fish"
   multi-term-dedicated-buffer-name                 "Dedicated Fish"
   multi-term-dedicated-close-back-to-open-buffer-p t
   multi-term-dedicated-max-window-height           14
   multi-term-dedicated-select-after-open-p         t
   multi-term-dedicated-skip-other-window-p         nil
   multi-term-dedicated-window-height               14
   multi-term-default-dir                           "~/"
   multi-term-program                               (first (split-string (shell-command-to-string "which fish") "\n"))
   multi-term-scroll-to-bottom-on-output            t
   multi-term-try-create                            nil
   multi-term-switch-after-close                    nil
   term-buffer-maximum-size                         10000
   term-suppress-hard-newline                       nil))

(provide 'shell-cfg)
;;; shell-cfg.el ends here
