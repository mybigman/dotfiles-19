;;; functions-cfg.el --- collection of general purpose custom functions

;;; Commentary:

;;; Code:

(defun my/def-key-for-maps (key cmd maps)
  "Set KEY to invoke CMD for all keymaps in MAPS."
  (mapcar (lambda (map) (define-key map key cmd)) maps))

(defun my/newline-and-indent ()
  "Will insert a new line in insert and normal states, with the position adjusted in the latter case."
  (interactive)
  (cond
   ((evil-normal-state-p)
    (progn
      (evil-append 1)
      (newline-and-indent)
      (evil-normal-state)))
   ((evil-insert-state-p)
    (newline-and-indent))))

(defun my/quick-backward ()
  "Quicker backward scrolling."
  (interactive)
  (evil-previous-visual-line 5))

(defun my/quick-forward ()
  "Quicker forward scrolling."
  (interactive)
  (evil-next-visual-line 5))

(defun my/what-face (point)
  "Reveal face at POINT."
  (interactive "d")
  (let ((face (or (get-char-property (point) 'read-face-name)
                  (get-char-property (point) 'face))))
    (if face (message "Face: %s" face) (message "No face at %d" point))))

(defun my/what-major-mode ()
  "Provides the exact name of the current major mode."
  (interactive) (message "%s" major-mode))

(defun my/switch-dict (dict)
  "Use DICT as Ispell dictionary."
  (message "Now using \"%s\" dictionary." dict)
  (setq-default ispell-dictionary dict)
  (if flyspell-mode
      (progn (flyspell-mode nil) (flyspell-mode t) (flyspell-buffer))))

(defun my/choose-dict ()
  "Use Helm to choose new Ispell dictionary."
  (interactive)
  (let ((dicts (ispell-valid-dictionary-list)))
    (helm :sources '((name       . "Choose new Ispell dictionary")
                     (candidates . dicts)
                     (action     . my/switch-dict)))))

(defun my/eval-last-sexp (eval-func)
  "Eval sexp with EVAL-FUNC compatible with evil normal state."
  (if (evil-normal-state-p)
      (progn
        (evil-append 1)
        (call-interactively eval-func)
        (evil-normal-state))
    (call-interactively eval-func)))

(defun my/dedicated-dired ()
  "Switch to or create dedicated dired buffer. Open dired in current buffer's location if prefix arg is provided."
  (interactive)
  (if current-prefix-arg (dired-jump)
    (let ((dired-buffer
           (cl-find-if
            (lambda (e) (string= "dired-mode" (buffer-local-value 'major-mode (get-buffer e))))
            (helm-buffer-list))))
      (if dired-buffer
          (switch-to-buffer dired-buffer)
        (dired "")))))

(defun my/add-all-if-not-contains (list &rest items)
  "Adds all `ITEMS' to `LIST' which it does not already contain."
  (dolist (item items)
    (if (not (-contains? list item))
        (add-to-list list item))))

(defun evil-half-cursor ()
  "Rewrite of evil's own function.
Will remove calls to redisplay that render ace modes unbearably slow.
See: https://bitbucket.org/lyro/evil/issue/472/evil-half-cursor-makes-evil-ace-jump-mode"
  (let (height)
    ;; make `window-line-height' reliable
    (setq height (window-line-height))
    (setq height (+ (nth 0 height) (nth 3 height)))
    ;; cut cursor height in half
    (setq height (/ height 2))
    (setq cursor-type (cons 'hbar height))
    ;; ensure the cursor is redisplayed
    (force-window-update (selected-window))))

(evil-define-operator evil-sp-delete (beg end type register yank-handler)
  "Call `evil-delete' with a balanced region. Redone without the final call to `indent-according-to-mode'."
  (interactive "<R><x><y>")
  (if (or (evil-sp--override)
          (= beg end)
          (and (eq type 'block)
               (evil-sp--block-is-balanced beg end)))
      (evil-delete beg end type register yank-handler)
    (condition-case nil
        (let ((new-beg (evil-sp--new-beginning beg end))
              (new-end (evil-sp--new-ending beg end)))
          (if (and (= new-end end)
                   (= new-beg beg))
              (evil-delete beg end type register yank-handler)
            (evil-delete new-beg new-end 'inclusive register yank-handler)))
      (error (let* ((beg (evil-sp--new-beginning beg end :shrink))
                    (end (evil-sp--new-ending beg end)))
               (evil-delete beg end type register yank-handler))))))

(evil-define-operator evil-sp-change (beg end type register yank-handler)
  "Call `evil-change' with a balanced region. Redone without the final call to `indent-according-to-mode'."
  (interactive "<R><x><y>")
  (if (or (evil-sp--override)
          (= beg end)
          (and (eq type 'block)
               (evil-sp--block-is-balanced beg end)))
      (evil-change beg end type register yank-handler)
    (condition-case nil
        (let ((new-beg (evil-sp--new-beginning beg end))
              (new-end (evil-sp--new-ending beg end)))
          (if (and (= new-end end)
                   (= new-beg beg))
              (evil-change beg end type register yank-handler)
            (evil-change new-beg new-end 'inclusive register yank-handler)))
      (error (let* ((beg (evil-sp--new-beginning beg end :shrink))
                    (end (evil-sp--new-ending beg end)))
               (evil-change beg end type register yank-handler))))))
(defun my/vimish-fold-dwim ()
  "Toggle fold, or create on if it does not exist."
  (interactive)
  (or (vimish-fold-toggle)
      (call-interactively 'vimish-fold)))



(provide 'functions-cfg)
;;; functions-cfg.el ends here
