(setq-local lexical-binding t)
(require 'dash)
(require 'f)
(require 'cl-lib)
(require 's)
(require 'evil)

(defgroup std nil
  "Std faces."
  :group 'std
  :prefix "std::")

(defmacro std::static-assert (predicate &optional error-msg &rest error-args)
  (declare (indent 1))
  `(unless ,predicate
     (error (apply #'format
                   (or ,error-msg "Assertion Failure")
                   (list ,@error-args)))))

(defmacro std::keybind (keymaps &rest keybinds)
  (declare (indent 1))
  (std::static-assert (= 0 (% (length keybinds) 2))
    "Uneven number of keybinds!")
  (unless (listp keymaps)
    (setq keymaps (list keymaps)))
  (-let [bind-forms nil]
    (while keybinds
      (-let [(key func . rest) keybinds]
        (-let [key (if (vectorp key) key `(kbd ,key))]
          (dolist (keymap keymaps)
            (push `(define-key ,keymap ,key ,func) bind-forms)))
        (setq keybinds rest)))
    `(progn ,@(nreverse bind-forms))))

(defmacro std::global-keybind (&rest binds)
  (std::static-assert (cl-evenp (length binds)))
  (-let [pairs nil]
    (while binds
      (push (cons
             (-let [key (pop binds)]
               (if (vectorp key)
                   key
                 `(kbd ,key)))
             (pop binds))
            pairs))
    `(progn
       ,@(--map
          `(global-set-key ,(car it) ,(cdr it))
          pairs))))

(defmacro std::evil-keybind (states keymaps &rest keybinds)
  (declare (indent 2))
  (std::static-assert (= 0 (% (length keybinds) 2))
    "Uneven number of keybinds!")
  (unless (listp keymaps)
    (setf keymaps (list keymaps)))
  (unless (listp states)
    (setf states (list states)))
  (-let [bind-forms nil]
    (while keybinds
      (-let [(key func . rest) keybinds]
        (-let [key (if (vectorp key) key `(kbd ,key))]
          (dolist (keymap keymaps)
            (push `(evil-define-key ',states ,keymap ,key ,func) bind-forms)))
        (setq keybinds rest)))
    `(progn ,@(nreverse bind-forms))))

(defmacro std::leader-keybind (&rest keybinds)
  (std::static-assert (= 0 (% (length keybinds) 2)) "Uneven number of keybinds!")
  `(spacemacs/set-leader-keys
     ,@keybinds))

(defmacro std::mode-leader-keybind (mode &rest keybinds)
  (declare (indent 1))
  (std::static-assert (= 0 (% (length keybinds) 2))
    "Uneven number of keybinds!")
  `(spacemacs/set-leader-keys-for-major-mode ,mode
     ,@keybinds))

(defmacro std::after (features &rest body)
  "Run BODY after loading FEATURE.
  Same as `with-eval-after-load', but there is no need to quote FEATURES."
  (declare (debug (sexp body)) (indent 1))
  (setf features (if (listp features) (nreverse features) (list features)))
  (let* ((module (pop features))
         (form `(with-eval-after-load
                    ,(if (stringp module)
                         module
                       `(quote ,module))
                  ,@body)))
    (while features
      (-let [module (pop features)]
        (setf form `(with-eval-after-load
                        ,(if (stringp module)
                             module
                           `(quote ,module))
                      ,form))))
    form))

(defmacro std::set-local (&rest binds)
  (std::static-assert (cl-evenp (length binds)))
  (-let [pairs nil]
    (while binds
      (push (cons (pop binds) (pop binds)) pairs))
    `(progn
       ,@(--map
          `(setq-local ,(car it) ,(cdr it))
          (nreverse pairs)))))

(defmacro std::fmt (str) `(s-lex-format ,str))

(defmacro std::idle (time repeat &rest body)
  (declare (indent 2))
  `(run-with-idle-timer
    ,time ,(eq repeat :repeat)
    ,(pcase body
       (`((function ,_)) (car body))
       (_ `(lambda () ,@body)))))

(cl-defmacro std::notify (title &key (txt "") (icon :NONE))
  (declare (indent 1))
  (-let [icon-arg
         (pcase icon
           (:NONE "--icon=emacs")
           ((pred stringp) (std::fmt "--icon=${icon}"))
           ((pred null)))]
    `(shell-command (format "notify-send '%s' '%s' %s" ,title ,txt ,icon-arg) nil nil)))

(defmacro std::add-hooks (cmd hooks)
  (declare (indent 1))
  `(progn
     ,@(--map `(add-hook ',it ,cmd)
             hooks)))

(defmacro std::autoload (&rest names)
  `(progn
     ,@(--map
        `(autoload ,it (std::fmt "${std::spacemacsdir}/autoloads"))
        names)))

(defmacro std::autoload-with (name features &rest body)
  (declare (indent 1))
  (-let [advice-name (intern (std::fmt "std::autoload-${name}-advice"))]
    `(progn
       (defun ,advice-name (old-fun &rest args)
         (dolist (feature ',features)
           (advice-remove feature #',advice-name)
           ,@body)
         (apply old-fun args))
       (dolist (feature ',features)
         (advice-add feature :around #',advice-name)))))

(defmacro std::idle-schedule (time repeat &rest body)
  (declare (indent 2))
  `(run-with-idle-timer
    ,time ,(eq repeat :repeat)
    ,(pcase body
       (`((function ,_)) (car body))
       (_ `(lambda () ,@body)))))

(defmacro std::if-version (v &rest body)
  (declare (indent 1))
  (when (version<= (number-to-string v) emacs-version)
    `(progn ,@body)))

(std::autoload 'std::what-face)
(std::global-keybind "C-x ö" #'std::what-face)

(std::autoload 'std::pacman-pkg-info)

(std::autoload 'std::jira::new-log-entry)

(std::autoload 'std::org-files)
(std::leader-keybind "aof" #'std::org-files)

(std::autoload 'std::fold-defun)
(define-key evil-normal-state-map (kbd "züf") #'std::fold-defun)

(std::autoload 'std::what-major-mode)
(std::global-keybind "C-x ä" #'std::what-major-mode)

(std::autoload 'std::edit-org-user-config)
(std::leader-keybind "feo" #'std::edit-org-user-config)

(std::autoload 'std::fill-dwim)
(std::global-keybind "M-q" #'std::fill-dwim)

(std::autoload 'std::schedule)

(std::autoload 'std::scratch)

(setq
 evil-normal-state-cursor   '("#ab3737" box)
 evil-insert-state-cursor   '("#33aa33" bar)
 evil-visual-state-cursor   '("#a374a8" box)
 evil-motion-state-cursor   '("#c97449" box)
 evil-operator-state-cursor '("#00688b" (hbar . 5))
 evil-emacs-state-cursor    '("#339999" bar)
 evil-resize-state-cursor   '("#ffdb1a" box))

(setq spacemacs-evil-cursors
      '(("normal"       "#ab3737"         box)
        ("insert"       "#33aa33"         (bar . 2))
        ("emacs"        "#339999"         box)
        ("hybrid"       "#339999"         (bar . 2))
        ("replace"      "#993333"         (hbar . 2))
        ("evilified"    "LightGoldenrod3" box)
        ("visual"       "gray"            (hbar . 2))
        ("motion"       "plum3"           box)
        ("lisp"         "HotPink1"        box)
        ("iedit"        "firebrick1"      box)
        ("iedit-insert" "firebrick1"      (bar . 2))))

(setq-default evil-escape-key-sequence "kj")

(evil-define-text-object std::evil::defun-object (count &optional beg end type)
  "Evil defun text object."
  (let ((start) (finish))
    (mark-defun)
    (setq start  (region-beginning)
          finish (region-end))
    (deactivate-mark)
    (evil-range start finish type )))

(define-key evil-operator-state-map "üf" #'std::evil::defun-object)

(evil-goggles-mode t)
(setq evil-goggles-duration                     0.15
      evil-goggles-pulse                        nil
      evil-goggles-enable-change                t
      evil-goggles-enable-delete                t
      evil-goggles-enable-indent                t
      evil-goggles-enable-yank                  t
      evil-goggles-enable-join                  t
      evil-goggles-enable-fill-and-move         t
      evil-goggles-enable-paste                 t
      evil-goggles-enable-shift                 t
      evil-goggles-enable-surround              t
      evil-goggles-enable-commentary            t
      evil-goggles-enable-nerd-commenter        t
      evil-goggles-enable-replace-with-register t
      evil-goggles-enable-set-marker            t
      evil-goggles-enable-undo                  t
      evil-goggles-enable-redo                  t)

(setq evil-move-beyond-eol t
      evil-want-fine-undo  t)

(std::after evil-escape
  (add-to-list 'evil-escape-excluded-major-modes 'org-agenda-mode)
  (add-to-list 'evil-escape-excluded-major-modes 'dired-mode))

(std::after ediff
  (evil-collection-init 'ediff))

(evil-lion-mode)

(evil-define-motion std::evil::forward-five-lines ()
  "Move the cursor 5 lines down."
  :type line
  (let (line-move-visual)
    (evil-line-move 5)))

(evil-define-motion std::evil::backward-five-lines ()
  "Move the cursor 5 lines up."
  :type line
  (let (line-move-visual)
    (evil-line-move -5)))

(std::keybind (evil-normal-state-map evil-visual-state-map evil-motion-state-map)
  "J" #'std::evil::forward-five-lines
  "K" #'std::evil::backward-five-lines)

(std::keybind (evil-motion-state-map evil-normal-state-map evil-visual-state-map evil-insert-state-map)
  "C-e" #'evil-end-of-visual-line
  "C-a" #'evil-beginning-of-visual-line)

(std::keybind evil-normal-state-map
  "C-j"   #'newline-and-indent
  "C-M-j" #'evil-join)

(std::keybind (evil-insert-state-map evil-normal-state-map evil-motion-state-map evil-evilified-state-map)
  "M-." #'xref-find-definitions)

(std::global-keybind "C-7" #'evilnc-comment-operator)

(std::after company
  (setq company-backends-emacs-lisp-mode
        '((company-capf company-files :with company-yasnippet)
          (company-dabbrev-code company-dabbrev))))

(font-lock-add-keywords
 'emacs-lisp-mode
 `((,(rx (group-n
          1
          (not (any "#"))
          "'"
          symbol-start
          (1+ (or (syntax word)
                  (syntax symbol)))
          symbol-end))
    1 font-lock-type-face)
   (,(rx (group-n
          1
          "#'")
         (group-n
          2
          symbol-start
          (1+ (or (syntax word)
                  (syntax symbol)))
          symbol-end))
    (1 font-lock-constant-face)
    (2 font-lock-function-name-face)))
 'append)

(std::autoload #'std::elisp::ielm #'std::elisp::fold-all-top-level-forms)

(std::mode-leader-keybind 'emacs-lisp-mode
  "'" #'std::elisp::ielm
  "C" #'std::elisp::fold-all-top-level-forms)

(std::after company
  (global-company-mode t))

(std::after company
  (dolist (buf (buffer-list))
    (unless (eq ?\ (aref (buffer-name buf) 0))
      (with-current-buffer buf
        (when (null company-backends)
          (-let [backends-var (intern (std::fmt "company-backends-${major-mode}"))]
            (setq-local company-backends
                        (if (boundp backends-var)
                            (symbol-value backends-var)
                          '((company-capf company-files :with company-yasnippet)
                            (company-dabbrev company-dabbrev-code company-keywords))))))))))

(std::after company
  (setq
   company-abort-manual-when-too-short t
   company-auto-complete               nil
   company-async-timeout               10
   company-dabbrev-code-ignore-case    nil
   company-dabbrev-downcase            nil
   company-dabbrev-ignore-case         nil
   company-etags-ignore-case           nil
   company-idle-delay                  10
   company-minimum-prefix-length       2
   company-require-match               nil
   company-selection-wrap-around       t
   company-show-numbers                t
   company-tooltip-flip-when-above     nil))

(std::after company
  (setq
   company-tooltip-minimum-width              70
   company-tooltip-align-annotations          t
   company-tooltip-margin                     2))

(std::after company
  (defconst std::company::backend-priorities
    '((company-fish-shell   . 10)
      (company-shell        . 11)
      (company-shell-env    . 12)
      (company-anaconda     . 10)
      (company-capf         . 50)
      (company-yasnippet    . 60)
      (company-keywords     . 70)
      (company-files        . 80)
      (company-dabbrev-code . 90)
      (company-dabbrev      . 100))
    "Alist of backends' priorities.  Smaller number means higher priority.")

  (define-inline std::company::priority-of-backend (backend)
    "Will retrieve priority of BACKEND.
Defauts to 999 if BACKEND is nul or has no priority defined."
    (inline-letevals (backend)
      (inline-quote
       (let ((pr (cdr (assoc ,backend std::company::backend-priorities))))
         (if (null pr) 999 pr)))))

  (defun std::company::priority-compare (c1 c2)
    "Compares the priorities of C1 & C2."
    (let* ((b1   (get-text-property 0 'company-backend c1))
           (b2   (get-text-property 0 'company-backend c2))
           (p1   (std::company::priority-of-backend b1))
           (p2   (std::company::priority-of-backend b2))
           (diff (- p1 p2)))
      (< diff 0)))

  (defun std::company::sort-by-backend-priority (candidates)
    "Will sort completion CANDIDATES according to their priorities."
    (sort (delete-dups candidates) #'std::company::priority-compare)))

(defun std::company::use-completions-priority-sorting ()
  (setq-local company-transformers '(company-flx-transformer company-sort-by-occurrence std::company::sort-by-backend-priority)))

(std::add-hooks #'std::company::use-completions-priority-sorting
  (rust-mode-hook fish-mode-hook python-mode-hook))

(std::after company-quickhelp

  (defun std::company::off (arg)
    "Use default keys when company is not active. ARG is ignored."
    (std::keybind (evil-normal-state-map evil-insert-state-map)
      "C-j" #'newline-and-indent
      "C-k" #'kill-line)
    (std::keybind evil-insert-state-map
      "C-l" #'yas-expand))

  (defun std::company::on (arg)
    "Use company's keys when company is active.
Necessary due to company-quickhelp using global key maps.
ARG is ignored."
    (std::keybind (evil-normal-state-map evil-insert-state-map)
      "C-j" #'company-select-next
      "C-k" #'company-select-previous)
    (std::keybind evil-insert-state-map
      "C-l" #'company-quickhelp-manual-begin))

  (add-hook 'company-completion-started-hook   #'std::company::on)
  (add-hook 'company-completion-finished-hook  #'std::company::off)
  (add-hook 'company-completion-cancelled-hook #'std::company::off)

  (define-key company-active-map (kbd "C-l") #'company-quickhelp-manual-begin))

(std::after company
  (company-flx-mode t)
  (setf company-flx-limit 300))

(std::global-keybind
 "C-SPC" #'company-complete
 "C-@"   #'company-complete)

(shackle-mode t)

(setq helm-display-function #'pop-to-buffer)

(setq shackle-rules
      '(("*helm-ag*"              :select t   :align right :size 0.5)
        ("*helm semantic/imenu*"  :select t   :align right :size 0.4)
        ("*helm org inbuffer*"    :select t   :align right :size 0.4)
        (magit-popup-mode         :select t   :align right :size 0.4)
        (flycheck-error-list-mode :select nil :align below :size 0.25)
        (compilation-mode         :select nil :align below :size 0.25)
        (messages-buffer-mode     :select t   :align below :size 0.25)
        (inferior-emacs-lisp-mode :select t   :align below :size 0.25)
        (ert-results-mode         :select t   :align below :size 0.5)
        (calendar-mode            :select t   :align below :size 0.25)
        (racer-help-mode          :select t   :align right :size 0.5)
        (help-mode                :select t   :align right :size 0.5)
        (helpful-mode             :select t   :align right :size 0.5)
        (" *Deletions*"           :select t   :align below :size 0.25)
        (" *Marked Files*"        :select t   :align below :size 0.25)
        ("*Org Select*"           :select t   :align below :size 0.33)
        ("*Org Note*"             :select t   :align below :size 0.33)
        ("*Org Links*"            :select t   :align below :size 0.2)
        (" *Org todo*"            :select t   :align below :size 0.2)
        ("*Man.*"                 :select t   :align below :size 0.5  :regexp t)
        ("*helm.*"                :select t   :align below :size 0.33 :regexp t)
        ("*Org Src.*"             :select t   :align right :size 0.5  :regexp t)))

(std::idle 1 :no-repeat (purpose-mode))

(std::after window-purpose
  (defun maybe-display-shackle (buffer alist)
    (and (shackle-display-buffer-condition buffer alist)
         (shackle-display-buffer-action buffer alist)))

  (setq purpose-action-sequences
        '((switch-to-buffer
           . (purpose-display-reuse-window-buffer
              purpose-display-reuse-window-purpose
              maybe-display-shackle
              purpose-display-maybe-same-window
              purpose-display-maybe-other-window
              purpose-display-maybe-other-frame
              purpose-display-maybe-pop-up-window
              purpose-display-maybe-pop-up-frame))

          (prefer-same-window
           . (purpose-display-maybe-same-window
              maybe-display-shackle
              purpose-display-reuse-window-buffer
              purpose-display-reuse-window-purpose
              purpose-display-maybe-other-window
              purpose-display-maybe-other-frame
              purpose-display-maybe-pop-up-window
              purpose-display-maybe-pop-up-frame))

          (force-same-window
           . (purpose-display-maybe-same-window
              maybe-display-shackle))

          (prefer-other-window

           . (purpose-display-reuse-window-buffer
              purpose-display-reuse-window-purpose
              maybe-display-shackle
              purpose-display-maybe-other-window
              purpose-display-maybe-pop-up-window
              purpose-display-maybe-other-frame
              purpose-display-maybe-pop-up-frame
              purpose-display-maybe-same-window))

          (prefer-other-frame
           . (purpose-display-reuse-window-buffer-other-frame
              purpose-display-reuse-window-purpose-other-frame
              maybe-display-shackle
              purpose-display-maybe-other-frame
              purpose-display-maybe-pop-up-frame
              purpose-display-maybe-other-window
              purpose-display-maybe-pop-up-window
              purpose-display-reuse-window-buffer
              purpose-display-reuse-window-purpose
              purpose-display-maybe-same-window)))))

(std::after window-purpose
  (setq purpose-user-mode-purposes
        '((flycheck-error-list-mode . bottom)
          (messages-buffer-mode     . bottom)
          (compilation-mode         . bottom)
          (calendar-mode            . bottom)
          (inferior-emacs-lisp-mode . bottom)))

  (purpose-compile-user-configuration))

(defun std::pop-to-messages-buffer (&optional arg)
  "Same as the spacemacs builtin, but uses `pop-to-buffer'.
  This ensures that shackle's (or purpose's) rules apply to the new window."
  (interactive "P")
  (-let [buf (messages-buffer)]
    (--if-let (get-buffer-window buf)
        (delete-window it)
      (with-current-buffer (messages-buffer)
        (goto-char (point-max))
        (if arg
            (switch-to-buffer-other-window (current-buffer))
          (pop-to-buffer (current-buffer)))))))

(std::leader-keybind "bm" #'std::pop-to-messages-buffer)

(defvar std::desktop-slot 11)

(defmacro* std::with-desktop (&key cmd check quit)
  "Create a wrapper do launch a command in its own eyebrowse desktop.

CMD is the function to wrap.
CHECK is a form to tets whether CMD needs to be run or if just switch the desk
top is sufficient.
QUIT is the exit command that will be adviced to also return to the previously
active desktop."
  (-let [slot std::desktop-slot]
    `(unless (get ,cmd 'std::has-desktop)
       (put ,cmd 'std::has-desktop t)
       (cl-incf std::desktop-slot)
       (advice-add
        ,quit :after
        (lambda () (eyebrowse-switch-to-window-config
               (get ,cmd 'std::return-to-desktop))))
       (advice-add
        ,cmd :around
        (lambda (func &rest args)
          (put ,cmd 'std::return-to-desktop (eyebrowse--get 'current-slot))
          (eyebrowse-switch-to-window-config ,slot)
          ;; a timer is needed because it looks like we are still in the old
          ;; buffer when the switch has happened
          (run-with-timer
           0 nil
           (lambda (check func args)
             (unless (funcall check)
               (apply func args)))
           (lambda () ,check) func args))))))

(eyebrowse-mode t)
(std::leader-keybind
 "1" #'eyebrowse-switch-to-window-config-1
 "2" #'eyebrowse-switch-to-window-config-2
 "3" #'eyebrowse-switch-to-window-config-3
 "4" #'eyebrowse-switch-to-window-config-4
 "5" #'eyebrowse-switch-to-window-config-5
 "6" #'eyebrowse-switch-to-window-config-6
 "7" #'eyebrowse-switch-to-window-config-7
 "8" #'eyebrowse-switch-to-window-config-8
 "9" #'eyebrowse-switch-to-window-config-9
 "0" #'eyebrowse-switch-to-window-config-0)

(setq winum-scope 'frame-local)
(winum-mode)

(std::keybind winum-keymap
  "M-1" #'winum-select-window-1
  "M-2" #'winum-select-window-2
  "M-3" #'winum-select-window-3
  "M-4" #'winum-select-window-4
  "M-5" #'winum-select-window-5
  "M-6" #'winum-select-window-6
  "M-7" #'winum-select-window-7
  "M-8" #'winum-select-window-8
  "M-9" #'winum-select-window-9)

(std::if-version 26

  (std::after helm (framey-mode))

  (std::after framey
    (setq framey-show-modeline nil))

  (std::autoload-with "Framey"
    (helpful-at-point)
    (require 'framey)))

(add-to-list 'window-persistent-parameters '(quit-restore . writable))

(std::leader-keybind "b C-d" #'kill-buffer-and-window)

(std::evil-keybind normal messages-buffer-mode-map
  "q" #'quit-window)

(std::after flycheck
  (std::keybind flycheck-error-list-mode-map
    "q" #'kill-buffer-and-window))

(std::after Man-mode
  (std::keybind Man-mode-map
    "q" #'kill-buffer-and-window))

(std::after helpful
  (std::evil-keybind (normal motion) helpful-mode-map
    "q" #'framey-quit-window))

(std::after lsp
  (setf lsp-ui-flycheck-live-reporting nil))

(std::after org
  (defun org-switch-to-buffer-other-window (&rest args)
    "Same as the original, but lacking the wrapping call to `org-no-popups'"
    (apply 'switch-to-buffer-other-window args)))

(std::after org
  (defun std::org::table-recalc ()
    "Reverse the prefix arg bevaviour of `org-table-recalculate', such that
by default the entire table is recalculated, while with a prefix arg recalculates
only the current cell."
    (interactive)
    (setq current-prefix-arg (not current-prefix-arg))
    (call-interactively #'org-table-recalculate)))

(std::after org
  (defun std::org::table-switch-right ()
    "Switch content of current table cell with the cell to the right."
    (interactive)
    (when (org-at-table-p)
      (std::org::table-switch (org-table-current-line) (1+ (org-table-current-column)))))

  (defun std::org::table-switch-left ()
    "Switch content of current table cell with the cell to the left."
    (interactive)
    (when (org-at-table-p)
      (std::org::table-switch (org-table-current-line) (1- (org-table-current-column)))))

  (defun std::org::table-switch (x2 y2)
    (let* ((p  (point))
           (x1 (org-table-current-line))
           (y1 (org-table-current-column))
           (t1 (org-table-get x1 y1))
           (t2 (org-table-get x2 y2)))
      (org-table-put x1 y1 t2)
      (org-table-put x2 y2 t1 t)
      (goto-char p))))

(std::after org
  (defun std::org::plot-table ()
    "Plot table at point and clear image cache.
The cache clearing will update tables visible as inline images."
    (interactive)
    (save-excursion
      (org-plot/gnuplot)
      (clear-image-cache))))

(std::after org-agenda
  (defun std::org::agenda-redo (&optional arg)
    (interactive "P")
    (org-agenda-redo arg)
    (writeroom-mode)))

(add-hook 'org-mode-hook #'std::org::mode-hook)
(std::autoload #'std::org::mode-hook #'std::org::agenda-list)
(std::global-keybind [remap org-agenda-list] #'std::org::agenda-list)

(setq-default org-directory          "~/Documents/Org/"
              org-default-notes-file (concat org-directory "Capture.org"))

(std::after org
  (setq org-startup-folded             t
        org-startup-indented           t
        org-startup-align-all-tables   t
        org-startup-with-inline-images nil))

(std::after org
  (add-to-list 'org-modules 'org-habit)
  (require 'org-habit))

(std::after org
  (setq
   org-special-ctrl-a         nil
   org-special-ctrl-k         nil
   org-special-ctrl-o         nil
   org-special-ctrl-a/e       nil
   org-ctrl-k-protect-subtree nil))

(std::after org-agenda

  (require 'german-holidays)

  (add-to-list 'org-agenda-files (concat org-directory "NT.org"))

  (when (string= "a-laptop" (system-name))
    (add-to-list 'org-agenda-files (concat org-directory "Privat.org")))

  (setq
   calendar-holidays                                holiday-german-BW-holidays
   org-agenda-include-diary                         t
   org-agenda-dim-blocked-tasks                     nil
   org-agenda-skip-scheduled-if-deadline-is-shown   t
   org-agenda-skip-scheduled-if-done                nil
   org-agenda-skip-scheduled-delay-if-deadline      nil
   org-agenda-skip-additional-timestamps-same-entry nil
   org-agenda-skip-deadline-prewarning-if-scheduled t
   org-agenda-span                                 14
   org-agenda-inhibit-startup                      t
   org-agenda-window-frame-fractions               '(0.7 . 0.7)
   org-agenda-window-setup                         'only-window
   org-deadline-warning-days                       7
   org-extend-today-until                          2
   org-agenda-block-separator                      ?\u2015
   org-todo-keyword-faces
   `(("INBOX" . (:background "#FFDDCC" :foreground "#1A1A1A" :weight bold :box (:line-width -1 :color "#000000")))
     ("PROJ"  . (:background "#5588BB" :foreground "#1A1A1A" :weight bold :box (:line-width -1 :color "#000000")))
     ("NEXT"  . (:background "#9f8b6f" :foreground "#1A1A1A" :weight bold :box (:line-width -1 :color "#000000")))
     ("TODO"  . (:background "#BB6666" :foreground "#1A1A1A" :weight bold :box (:line-width -1 :color "#000000")))
     ("DONE"  . (:background "#66AA66" :foreground "#1A1A1A" :weight bold :box (:line-width -1 :color "#000000")))
     ("WAIT"  . (:background "#999999" :foreground "#1A1A1A" :weight bold :box (:line-width -1 :color "#000000")))))

  (setf
   org-agenda-custom-commands
   `(("n" "Agenda"
      ((todo "INBOX"
             ((org-agenda-overriding-header
               (concat (propertize "" 'display '(raise 0.15))" Inbox"))
              (org-agenda-sorting-strategy '(todo-state-up))))

       (todo "PROJ"
             ((org-agenda-overriding-header
               (concat (propertize "" 'display '(raise 0.15))" Projects"))
              (org-agenda-sorting-strategy '(category-up priority-down))))

       (todo "NEXT"
             ((org-agenda-overriding-header
               (concat (propertize "" 'display '(raise 0.15)) " Next Tasks"))
              (org-agenda-sorting-strategy '(priority-down category-up))))

       (todo "TODO"
             ((org-agenda-overriding-header
               (concat (propertize "" 'display '(raise 0.15)) " COLLECTBOX (Unscheduled)"))
              (org-agenda-skip-function
               '(org-agenda-skip-entry-if 'scheduled 'deadline))))

       (todo "WAIT"
             ((org-agenda-overriding-header
               (concat (propertize "" 'display '(raise 0.15)) " Waiting"))
              (org-agenda-sorting-strategy '(todo-state-up))))

       (agenda "" nil)

       )))))

(std::after org-habit
  (setq org-habit-graph-column               70
        org-habit-preceding-days             21
        org-habit-following-days             7
        org-habit-show-habits-only-for-today nil))

(std::after org
  (setq-default org-bullets-bullet-list '("✿")))

(font-lock-add-keywords
 'org-mode
 '(("^ +\\([-*]\\) " (0 (prog1 () (compose-region (match-beginning 1) (match-end 1) "•"))))))

(std::after org-capture
  (defun std::org::capture-helper (path)
    "Move to olp PATH and select the next headline."
    (goto-char (org-find-olp path :this-buffer))
    (org-element-cache-refresh (point))
    (let* ((context (-> (org-element-context) (cadr)))
           (start (plist-get context :begin))
           (end (plist-get context :end))
           (data (save-restriction
                   (org-element-cache-refresh (point))
                   (narrow-to-region start end)
                   (org-element-parse-buffer 'headline)))
           (headline (caddr data))
           (headlines (cddr headline))
           (selections (--map (plist-get (cadr it) :raw-value)
                              headlines))
           (selection (completing-read ">_ " (cons "New Entry" selections))))
      (when (string= selection "New Entry")
        (forward-line)
        (insert (make-string (1+ (plist-get (cadr headline) :level)) ?*)
                (concat " " (setq selection (read-string ">_")))
                "\n"))
      selection)))

(std::after org-capture
  (defun std::org::haushalt-capture ()
    (let* ((sub-entry (std::org::capture-helper '("Haushalt")))
           (path `("Haushalt" ,sub-entry)))
      (if (string= sub-entry "Versicherungen")
          (setf path (nconc path (list (std::org::capture-helper path) (format-time-string "%Y"))))
        (setf path (nconc path (list (format-time-string "%Y")))))
      (goto-char (org-find-olp path :this-buffer))
      (org-element-cache-refresh (point))
      (-> (org-element-context) (cadr) (plist-get :end) (goto-char)))))

(std::after org-capture
  (defun std::org:::bookmark-capture ()
    (let* ((olp `("Lesezeichen" ,(format-time-string "%Y")))
           (sub-entry (std::org::capture-helper olp))
           (path (nconc olp (list sub-entry))))
      (goto-char (org-find-olp path :this-buffer)))))

(std::after org-capture
  (defun std::org::sprint-capture ()
    (goto-char (org-find-olp '("XENTRY" "Sprints") :this-buffer))
    (org-element-cache-refresh (point))
    (let* ((context (car (cdr (org-element-context))))
           (start (plist-get context :begin))
           (end (plist-get context :end))
           (sprints (save-restriction
                      (org-element-cache-refresh (point))
                      (narrow-to-region start end)
                      (org-element-map (org-element-parse-buffer 'headline) 'headline
                        (lambda (it)
                          (when (equal 3 (org-element-property :level it))
                            (org-element-property :raw-value it))))))
           (sorted (sort sprints
                         (lambda (s1 s2)
                           (> (string-to-number s1) (string-to-number s2))))))
      (goto-char (org-find-olp `("XENTRY" "Sprints" ,(car sorted)) :this-buffer)))))

(std::after org

  (setq
   org-capture-bookmark t
   org-capture-templates
   `(("p" "Privat")

     ("pp" "Inbox" entry
      (file+olp ,(concat org-directory "Privat.org") "Inbox")
      "* INBOX %i%?\n%(format-time-string (car org-time-stamp-formats) (time-add (current-time) (time-add 0 (* 60 60 24 10))))")

     ("ph" "Haushalt Eintrag" plain
      (file+function ,(concat org-directory "Privat.org") std::org::haushalt-capture)
      "%u\n%?"
      :empty-lines 1)

     ("pt" "Privater Termin" entry
      (file+olp ,(concat org-directory "Privat.org") "Termine und Aufgaben" "2020" "Termine")
      "* %?\n %U")

     ("pa" "Private Aufgabe" entry
      (file+olp ,(concat org-directory "Privat.org") "Termine und Aufgaben" "2020" "Einzelaufgaben")
      "* TODO %?\nDEADLINE: %t SCHEDULED: %t")

     ("pg" "Private Gewohnheit" entry
      (file+olp ,(concat org-directory "Privat.org") "Termine und Aufgaben" "2020" "Regelmäßige Gewohnheiten")
      ,(concat "* TODO %?\n"
               "SCHEDULED: %t\n"
               ":PROPERTIES:\n"
               ":STYLE:    habit\n"
               ":END:\n"))

     ("pl" "Lesezeichen" checkitem
      (file+function ,(concat org-directory "Privat.org") std::org:::bookmark-capture)
      "[ ] %c")

     ("n" "NT")
     ("nn" "Inbox" entry
      (file+olp ,(concat org-directory "NT.org") "Inbox")
      "* INBOX %i%?\n%(format-time-string (car org-time-stamp-formats) (time-add (current-time) (time-add 0 (* 60 60 24 10))))")

     ("ns" "Sprint Eintrag" entry
      (file+function ,(concat org-directory "NT.org") std::org::sprint-capture)
      "* %?"))))

(std::after org
  (setq org-table-auto-blank-field        nil
        org-table-use-standard-references t))

(std::after org
  (setq org-edit-src-auto-save-idle-delay           0
        org-edit-src-turn-on-auto-save              nil
        org-src-fontify-natively                    t
        org-strc-preserve-indentation               nil
        org-edit-src-content-indentation            2
        org-src-ask-before-returning-to-edit-buffer nil
        org-src-window-setup                        'other-window))

(std::after org
  (setq org-export-use-babel nil))

(std::after org

  (setf (nthcdr 4 org-emphasis-regexp-components) '(3))

  (setq
   calendar-date-style                     'european
   org-tags-column                         85
   org-closed-keep-when-no-todo            nil
   org-use-fast-todo-selection             t
   org-enforce-todo-dependencies           t
   org-enforce-todo-checkbox-dependencies  t
   org-list-demote-modify-bullet           '(("+" . "-") ("-" . "+") ("*" . "+"))
   org-list-indent-offset                  1
   org-log-done                            'time
   org-ellipsis                            " "
   org-footnote-section                    "Footnotes"
   org-log-into-drawer                     t
   org-table-use-standard-references       nil
   org-cycle-emulate-tab                   t
   org-cycle-global-at-bob                 nil
   org-M-RET-may-split-line                nil
   org-fontify-whole-heading-line          nil
   org-catch-invisible-edits               'show
   org-refile-targets                      '((nil . (:maxlevel . 10)))
   org-footnote-auto-adjust                t
   org-file-apps                           '((auto-mode . emacs)
                                             ("\\.mm\\'" . default)
                                             ("\\.eml\\'" . "thunderbird \"%s\"")
                                             ("\\.x?html?\\'" . default)
                                             ("\\.pdf\\'" . default))
   org-show-context-detail                 '((agenda . local)
                                             (bookmark-jump . lineage)
                                             (isearch . lineage)
                                             (default . ancestors)))

  (setq-default
   org-display-custom-times nil
   ;; org-time-stamp-formats   '("<%Y-%m-%d %a>" . "<%Y-%m-%d %a %H:%M>")
   ))
;;  org-catch-invisible-edits      'show
;;  org-fontify-whole-heading-line nil
;;  ;; org-hide-block-overlays
;;  org-hide-emphasis-markers      t
;;  org-list-indent-offset         1
;;  org-list-allow-alphabetical    nil

(defmacro std::org::use-babel-use-languages (&rest langs)
  (-let [forms nil]
    (dolist (lang langs)
      (push
       `(progn
          (autoload ',(intern (concat "org-babel-execute:" lang)) ,(concat "ob-" lang))
          (autoload ',(intern (concat "org-babel-expand-body:" lang)) ,(concat "ob-" lang)))
       forms))
    `(progn ,@forms)))

(std::after org
  (std::org::use-babel-use-languages
   "emacs-lisp" "sh" "python" "shell" "gnuplot" "http"))

(defface std::result-face
  `((t (:foreground "#886688" :bold t)))
  "Face for '==>'."
  :group 'std)

  (font-lock-add-keywords
   'org-mode
   '(("==>" . 'std::result-face)))

(std::after org
  (std::mode-leader-keybind 'org-mode
    "rr" #'org-reveal
    "rb" #'outline-show-branches
    "rc" #'outline-show-children
    "ra" #'outline-show-all))

(std::after org
  (std::mode-leader-keybind 'org-mode
    "u"   #'outline-up-heading
    "M-u" #'helm-org-parent-headings
    "j"   #'org-next-visible-heading
    "k"   #'org-previous-visible-heading
    "C-j" #'org-forward-heading-same-level
    "C-k" #'org-backward-heading-same-level))

(std::after org
  (std::mode-leader-keybind 'org-mode
    "s"  nil
    "ss" #'org-schedule
    "st" #'org-time-stamp
    "sd" #'org-deadline))

(std::after org
  (std::mode-leader-keybind 'org-mode
    "wi" #'org-tree-to-indirect-buffer
    "wm" #'org-mark-subtree
    "wd" #'org-cut-subtree
    "wy" #'org-copy-subtree
    "wY" #'org-clone-subtree-with-time-shift
    "wp" #'org-paste-subtree
    "wr" #'org-refile))

(std::after org
  (dolist (mode '(normal insert))
    (evil-define-key mode org-mode-map
      (kbd "M-RET") #'org-meta-return
      (kbd "M-h")   #'org-metaleft
      (kbd "M-l")   #'org-metaright
      (kbd "M-j")   #'org-metadown
      (kbd "M-k")   #'org-metaup
      (kbd "M-H")   #'org-shiftmetaleft
      (kbd "M-L")   #'org-shiftmetaright
      (kbd "M-J")   #'org-shiftmetadown
      (kbd "M-K")   #'org-shiftmetaup
      (kbd "M-t")   #'org-insert-todo-heading-respect-content)))

(std::after org
  (std::mode-leader-keybind 'org-mode
    "7"   #'org-sparse-tree
    "8"   #'org-occur
    "M-j" #'next-error
    "M-k" #'previous-error))

(std::after org
  (std::mode-leader-keybind 'org-mode
    "n"  nil
    "nb" #'org-narrow-to-block
    "ne" #'org-narrow-to-element
    "ns" #'org-narrow-to-subtree
    "nw" #'widen))

(std::after org
  (std::mode-leader-keybind 'org-mode
    "c"  nil
    "cc" #'org-clock-in
    "cx" #'org-clock-out
    "cd" #'org-clock-display
    "cq" #'org-clock-remove-overlays
    "cg" #'spacemacs/org-clock-jump-to-current-clock))

(std::after org
  (std::mode-leader-keybind 'org-mode
    "if" #'org-footnote-new
    "il" #'org-insert-link
    "in" #'org-add-note
    "id" #'org-insert-drawer
    "ii" #'org-time-stamp-inactive
    "iI" #'org-time-stamp))

(std::after org
  ;; TODO: rebind clock
  (spacemacs/set-leader-keys-for-major-mode 'org-mode "q" nil)

  (std::mode-leader-keybind 'org-mode
    "t"   nil
    "tb"  #'org-table-blank-field
    "ty"  #'org-table-copy-region
    "tt"  #'org-table-create-or-convert-from-region
    "tx"  #'org-table-cut-region
    "te"  #'org-table-edit-field
    "tv"  #'org-table-eval-formula
    "t-"  #'org-table-insert-hline
    "tp"  #'org-table-paste-rectangle
    "t#"  #'org-table-rotate-recalc-marks
    "t0"  #'org-table-sort-lines
    "to"  #'org-table-toggle-coordinate-overlays
    "tg"  #'std::org::plot-table
    "tf"  #'std::org::table-recalc
    "tsl" #'std::org::table-switch-right
    "tsh" #'std::org::table-switch-left
    "+"   #'org-table-sum
    "?"   #'org-table-field-info))

(std::after org
  (std::mode-leader-keybind 'org-mode
    "zh" #'org-toggle-heading
    "zl" #'org-toggle-link-display
    "zx" #'org-toggle-checkbox
    "zc" #'org-toggle-comment
    "zt" #'org-toggle-tag
    "zi" #'org-toggle-item
    "zo" #'org-toggle-ordered-property))

(std::global-keybind "<f12>" #'std::org::agenda-list)

(std::after org-agenda
  (std::evil-keybind 'evilified org-agenda-mode-map
    "J" #'std::evil::forward-five-lines
    "K" #'std::evil::backward-five-lines
    [remap org-agenda-redo] #'std::org::agenda-redo)

  (std::mode-leader-keybind 'org-agenda-mode
    "zh" #'org-habit-toggle-habits))

(std::after org
  (std::keybind org-src-mode-map
    [remap save-buffer] #'ignore
    "C-c C-c" #'org-edit-src-exit)

  (std::mode-leader-keybind 'org-mode
    "bt" #'org-babel-tangle
    "bv" #'org-babel-tangle-file))

(std::after org

  (std::keybind org-mode-map
    "M-q" #'std::fill-dwim)

  (std::mode-leader-keybind 'org-mode
    "0"   #'org-sort
    "#"   #'org-update-statistics-cookies
    "C-y" #'org-copy-visible
    "C-p" #'org-set-property
    "C-f" #'org-footnote-action
    "C-o" #'org-open-at-point
    "C-e" #'org-edit-special
    "C-t" #'org-set-tags-command
    "P"   #'org-priority)

  (std::evil-keybind 'normal org-mode-map
    "-" #'org-cycle-list-bullet
    "t" #'org-todo))

(std::autoload #'std::shell::mode-hook)
(std::add-hooks #'std::shell::mode-hook
  (term-mode-hook eshell-mode-hook))

(std::after multi-term
  (setq multi-term-program (s-trim (shell-command-to-string "which fish"))))

(add-hook 'fish-mode-hook #'std::fish::mode-hook)
(std::autoload #'std::fish::mode-hook)

(std::after company
  (setq
   company-shell-delete-duplicates nil
   company-shell-modes             nil
   company-fish-shell-modes        nil
   company-shell-use-help-arg      t)

  (setq company-backends-fish-mode
        '((company-dabbrev-code company-files company-shell company-shell-env company-fish-shell :with company-yasnippet))))

(defconst std::fish::imenu-expr
  (list
   (list
    "Function"
    (rx (group-n 1 (seq bol "function" (1+ space)))
        (group-n 2 (1+ (or alnum (syntax symbol)))) symbol-end)
    2)

   (list
    "Variables"
    (rx bol "set" (1+ space) (0+ "-" (1+ alpha) (1+ space))
        (group-n 1 symbol-start (1+ (or word "_"))))
    1)))

(std::autoload-with "Helm"
  (completing-read
    read-directory-name
    read-string read-from-minibuffer
    std::org-files)
  (require 'helm))

(std::autoload #'std::org-helm-headings #'std::helm-semantic-or-imenu)

(std::after helm
  (setq
   helm-ag-base-command              "ag -f --nocolor --nogroup --depth 999999 --smart-case --recurse"
   helm-imenu-delimiter              ": "
   helm-move-to-line-cycle-in-source t
   helm-swoop-use-line-number-face   t))

(std::leader-keybind
  "hi"  #'std::helm-semantic-or-imenu
  "saa" #'helm-do-ag-this-file)

(std::after helm
  (std::keybind helm-map
    "M-j" #'helm-next-source
    "M-k" #'helm-previous-source))

(std::after rust-mode
  (defun std::rust::build-rusty-tags ()
    (interactive)
    (make-thread
     (lambda ()
       (-let [default-directory (projectile-project-root)]
         (call-process-shell-command "rusty-tags emacs")
         (call-process-shell-command "mv rusty-tags.emacs TAGS")
         (message "Rusty tags rebuilt."))))))

(std::after "racer"
  (evil-define-key 'normal racer-mode-map      (kbd "M-.") #'racer-find-definition)
  (evil-define-key 'insert racer-mode-map      (kbd "M-.") #'racer-find-definition)
  (evil-define-key 'normal racer-help-mode-map (kbd "q")   #'kill-buffer-and-window)

  (std::mode-leader-keybind 'rust-mode
    "f"   #'rust-format-buffer
    "a"   #'rust-beginning-of-defun
    "e"   #'rust-end-of-defun
    "d"   #'racer-describe
    "C-t" #'std::rust::build-rusty-tags))

(std::after "rust-mode"
  (setq racer-rust-src-path "~/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/src"
        company-backends-rust-mode
        '((company-capf :with company-dabbrev-code company-yasnippet)
          (company-dabbrev-code company-gtags company-etags company-keywords :with company-yasnippet)
          (company-files :with company-yasnippet)
          (company-dabbrev :with company-yasnippet))))

(std::after projectile
  (std::leader-keybind
    "pg"  nil
    "pt"  #'projectile-find-tag
    "psa" #'helm-projectile-ag
    "pgs" #'std::projectile::magit-status
    "pC"  #'projectile-cleanup-known-projects))

(std::after projectile
  (setq projectile-switch-project-action #'project-find-file))

(std::autoload
 #'std::flycheck::next-error
 #'std::flycheck::previous-error)

(std::after flycheck
  (setq
   flycheck-check-syntax-automatically '(mode-enabled save idle-change)
   flycheck-idle-change-delay          10
   flycheck-pos-tip-timeout            999))

(std::after flycheck

  (evil-leader/set-key
    "ee"    #'flycheck-buffer
    "e C-e" #'flycheck-mode)

  (define-key evil-normal-state-map (kbd "C-.") #'std::flycheck::next-error)
  (define-key evil-normal-state-map (kbd "C-,") #'std::flycheck::previous-error))

(std::after magit
  (defun std::magit::org-reveal-on-visit ()
    (when (eq 'org-mode major-mode)
      (org-reveal)))
  (add-hook 'magit-diff-visit-file-hook #'std::magit::org-reveal-on-visit))

(std::after magit
  (setq
   magit-display-buffer-function              #'magit-display-buffer-fullframe-status-v1
   magit-repository-directories               '(("~/Documents/git/" . 1))
   magit-save-repository-buffers              'dontask
   git-commit-summary-max-length              120
   magit-section-visibility-indicator         nil
   magit-diff-highlight-hunk-region-functions '(magit-diff-highlight-hunk-region-using-face)))

(std::after git-gutter
  (setq git-gutter-fr:side 'left-fringe))

(std::after magit
  (std::keybind
      (magit-mode-map
       magit-status-mode-map
       magit-log-mode-map
       magit-diff-mode-map
       magit-branch-section-map
       magit-untracked-section-map
       magit-file-section-map
       magit-status-mode-map
       magit-hunk-section-map
       magit-stash-section-map
       magit-stashes-section-map
       magit-staged-section-map
       magit-unstaged-section-map)
    "J"   #'std::evil::forward-five-lines
    "K"   #'std::evil::backward-five-lines
    "M-j" #'magit-section-forward-sibling
    "M-k" #'magit-section-backward-sibling
    ",u"  #'magit-section-up
    ",u"  #'magit-section-up
    ",1"  #'magit-section-show-level-1-all
    ",2"  #'magit-section-show-level-2-all
    ",3"  #'magit-section-show-level-3-all
    ",4"  #'magit-section-show-level-4-all
    "M-1" #'winum-select-window-1
    "M-2" #'winum-select-window-2
    "M-3" #'winum-select-window-3
    "M-4" #'winum-select-window-4))

(defvar std::dired::saved-positions nil)
(defvar std::dired::saved-window-config nil)
(defvar std::dired::cache-file (f-join user-emacs-directory ".cache" "std-dired-cache"))

(std::after dired
  (evil-define-state dired
    "Dired state"
    :cursor '(bar . 0)
    :enable (motion)))

(std::autoload
 #'std::dired #'std::dired::mode-hook)

(std::after dired+

  (defhydra std::dired::goto-hydra (:exit t :hint nil)
    ("h" (lambda () (interactive) (dired "~"))           "$HOME")
    ("d" (lambda () (interactive) (dired "~/Documents")) "Documents")
    ("w" (lambda () (interactive) (dired "~/Downloads")) "Downloads")
    ("v" (lambda () (interactive) (dired "~/Videos"))    "Videos")
    ("o" (lambda () (interactive) (dired "~/Dropbox"))   "Dropbox")
    ("p" (lambda () (interactive) (dired "~/Pictures"))  "Pictures")
    ("m" (lambda () (interactive) (dired "~/Music"))     "Music")
    ("M" (lambda () (interactive) (dired "/run/media"))  "/run/media")
    ("q" nil "cancel"))

  (defun std::dired::quit ()
    (interactive)
    (let ((left) (right))
      (winum-select-window-1)
      (setf left default-directory)
      (winum-select-window-2)
      (setf right default-directory
            std::dired::saved-positions (list left right))
      (unless (f-exists? std::dired::cache-file)
        (f-touch std::dired::cache-file))
      (f-write (std::fmt "${left}\n${right}") 'utf-8 std::dired::cache-file))
    (set-window-configuration std::dired::saved-window-config)
    (--each (buffer-list)
      (when (eq 'dired-mode (buffer-local-value 'major-mode it))
        (kill-buffer it))))

  (defun std::dired::mark-up ()
    (interactive)
    (call-interactively #'dired-mark)
    (forward-line -2))

  (defun std::dired::open-externally ()
    (interactive)
    (let* ((files (or (dired-get-marked-files :local)
                      (dired-get-filename)))
           (types (->> files
                       (-map #'file-name-extension)
                       (-map #'mailcap-extension-to-mime)))
           (videos? (--all? (s-starts-with? "video" it) types))
           (cmd (if videos? "mpv" "xdg-open")))
      (call-process-shell-command
       (format "%s %s &"
               cmd
               (->> files
                    (-map #'shell-quote-argument)
                    (s-join " "))))))

  (defun std::dired::filesize ()
    (interactive)
    (-if-let (file (dired-get-filename nil :no-error))
        (let* ((cmd (if (f-directory? file) "du -sh \"%s\"" "ls -sh \"%s\""))
               (output (->> file
                            (format cmd)
                            ;; (shell-quote-argument)
                            (shell-command-to-string)
                            (s-trim))))
          (-let [(size file) (s-split-up-to (rx (1+ whitespace)) output 1)]
            (message
             "%s : %s"
             (propertize file 'face 'font-lock-keyword-face)
             (propertize size 'face 'font-lock-string-face))))
      (message (propertize "---" 'face 'font-lock-string-face)))))

(std::after wdired

  (defun std::dired::finish-wdired ()
    (interactive)
    (wdired-finish-edit)
    (evil-dired-state))

  (defun std::dired::abort-wdired ()
    (interactive)
    (wdired-abort-changes)
    (evil-dired-state)))

(add-hook 'dired-mode-hook #'std::dired::mode-hook)

(std::after dired+
  (setf dired-listing-switches "-alh --group-directories-first")
  (unless (file-exists-p std::dired::cache-file)
    (f-touch std::dired::cache-file)))

(std::leader-keybind "ad" #'std::dired)

(defmacro std::dired::dwim-target-wrap (command)
  (let* ((command (cadr command))
         (command-name (symbol-name command))
         (format-name (s-replace "dired-" "dired::" (symbol-name command)))
         (new-name (format (if (s-starts-with? "dired" format-name)
                               "std::%s"
                             "std::dired::%s")
                           format-name)))
    (-let [name (intern new-name)]
      `(progn
         (defun ,name (&optional arg)
           ,(format "Run %s. Set `dired-dwim-target' to t with a prefix arg." command-name)
           (interactive "P")
           (-let [dired-dwim-target arg] (,command)))
         #',name))))

;; (std::after dired+

;;   (std::dired::dwim-target-wrap #'dired-do-copy)
;;   (std::dired::dwim-target-wrap #'dired-do-rename)
;;   (std::dired::dwim-target-wrap #'dired-do-symlink)

;;   (std::keybind evil-dired-state-map
;;     "o"     nil
;;     ","     nil
;;     "c"     nil
;;     "RET"   #'dired-find-file
;;     "gh"    #'std::dired::goto-hydra/body
;;     "gr"    #'revert-buffer
;;     "y"     #'std::dired::do-copy
;;     "R"     #'std::dired::do-rename
;;     "S"     #'std::dired::do-symlink
;;     "cd"    #'dired-create-directory
;;     ", C-e" #'wdired-change-to-wdired-mode
;;     "("     #'global-dired-hide-details-mode
;;     "D"     #'dired-do-delete
;;     "I"     #'std::dired::filesize
;;     "ox"    #'std::dired::open-externally
;;     "q"     #'std::dired::quit
;;     "J"     #'std::evil::forward-five-lines
;;     "K"     #'std::evil::backward-five-lines
;;     "M-j"   #'dired-mark
;;     "M-k"   #'std::dired::mark-up
;;     "l"     #'dired-find-file
;;     "h"     #'diredp-up-directory
;;     "Z"     #'dired-do-compress
;;     "M-z"   #'dired-do-compress-to)

;;   (std::after wdired
;;     (std::keybind wdired-mode-map
;;       "C-c C-c" #'std::dired::finish-wdired
;;       "C-c C-k" #'std::dired::abort-wdired)))

(defface spacemacs-treemacs-face
  `((t (:foreground "#1a1a1a" :background "MediumPurple1")))
  "Custom spacemacs-treemacs face for the modeline."
  :group 'std)

(defun std::elisp::treemacs-flycheck-activate ()
  (when (s-matches? (rx "treemacs" (0+ (or "-" (1+ alnum))) ".el")
                    (buffer-name))
    (flycheck-mode)))
(add-hook 'find-file-hook #'std::elisp::treemacs-flycheck-activate)

(use-package treemacs
  :if (file-exists-p "~/Documents/git/treemacs/")
  :load-path "~/Documents/git/treemacs/src/elisp"
  :defer t
  :init
  (std::after winum
    (define-key winum-keymap (kbd "M-0") #'treemacs-select-window))
  :config
  (progn
    (setq treemacs-follow-after-init          t
          treemacs-width                      35
          treemacs-indentation                2
          treemacs-collapse-dirs              3
          treemacs-silent-refresh             nil
          treemacs-change-root-without-asking nil
          treemacs-sorting                    'alphabetic-asc
          treemacs-show-hidden-files          t
          treemacs-never-persist              nil
          treemacs-goto-tag-strategy          'refetch-index)
    (treemacs-follow-mode t)
    (treemacs-filewatch-mode t))
  :bind
  (:map global-map
        ("M-0"       . treemacs-select-window)
        ("C-c 1"     . treemacs-delete-other-windows)
        :map spacemacs-default-map
        ("ft"    . treemacs)
        ("f C-t" . treemacs-find-file)))

(use-package treemacs-evil
  :if (file-exists-p "~/Documents/git/treemacs/")
  :load-path "~/Documents/git/treemacs/src/extra"
  :after treemacs)

(use-package treemacs-projectile
  :if (file-exists-p "~/Documents/git/treemacs/")
  :load-path "~/Documents/git/treemacs/src/extra"
  :after treemacs)

(use-package treemacs-icons-dired
  :if (file-exists-p "~/Documents/git/treemacs/")
  :after dired
  :load-path "~/Documents/git/treemacs/src/extra"
  :config (treemacs-icons-dired-mode))

(use-package treemacs-magit
  :if (file-exists-p "~/Documents/git/treemacs/")
  :defer t
  :load-path "~/Documents/git/treemacs/src/extra"
  :after (treemacs magit))

(use-package treemacs-persp
  :if (file-exists-p "~/Documents/git/treemacs/")
  :defer t
  :load-path "~/Documents/git/treemacs/src/extra"
  :after (treemacs persp-mode))

(setf treemacs-no-delete-other-windows nil)

(defvar std::ledger::save-window-config nil)
(defconst std::ledger::month-separator-pattern (rx "+++ " (group-n 2 (1+ any)) " +++" eol))
(defconst std::ledger::dir (expand-file-name (std::fmt "${std::orgdir}/Ledger")))
(defconst std::ledger::months '((1 . "Januar")   (2 . "Februar")   (3 . "März")
                                (4 . "April")    (5 . "Mai")       (6 . "Juni")
                                (7 . "Juli")     (8 . "August")    (9 . "September")
                                (10 . "Oktober") (11 . "November") (12 . "Dezemper")))

(std::autoload
 #'std::ledger
 #'std::ledger::mode-hook)
(add-hook 'ledger-mode-hook #'std::ledger::mode-hook)

(std::after ledger-mode
  (defun std::ledger::save ()
    "First `ledger-mode-clean-buffer', then `save-buffer'."
    (interactive)
    (-let [p (point)]
      (when (buffer-modified-p)
        (unwind-protect (ledger-mode-clean-buffer)
          (save-buffer)))
      (goto-char p))))

(std::after ledger-mode
  (defun std::ledger::finish ()
    (interactive)
    (cl-loop
     for buf in (buffer-list)
     if (eq 'ledger-mode (buffer-local-value 'major-mode buf)) do
     (with-current-buffer buf
       (when (buffer-file-name)
         (save-buffer)
         (kill-buffer))))
    (when std::ledger::save-window-config
      (set-window-configuration std::ledger::save-window-config))))

(std::after ledger-mode
  (defun std::ledger::magic-tab ()
    (interactive)
    (if (s-matches? outline-regexp (thing-at-point 'line t))
        (outline-toggle-children)
      (ledger-magic-tab))))

(std::after ledger-mode
  (defun std::ledger::goto-current-month ()
    (interactive)
    (-let [month (-> (calendar-current-date)
                     (car)
                     (alist-get std::ledger::months))]
      (save-match-data
        (-let [start (point)]
          (goto-char 0)
          (if (search-forward (std::fmt "+++ ${month}") nil :no-error)
              (forward-line 1)
            (message "'%s' not found." month)
            (goto-char start)))))))

(std::after ledger-mode
  (defun std::ledger::forward ()
    (interactive)
    (if (s-matches? std::ledger::month-separator-pattern
                    (thing-at-point 'line))
        (save-match-data
          (end-of-line)
          (search-forward-regexp std::ledger::month-separator-pattern nil :no-error))
      (call-interactively #'evil-ledger-forward-xact)))

  (defun std::ledger::backward ()
    (interactive)
    (if (s-matches? std::ledger::month-separator-pattern
                    (thing-at-point 'line))
        (save-match-data
          (beginning-of-line)
          (search-backward-regexp std::ledger::month-separator-pattern nil :no-error))
      (call-interactively #'evil-ledger-backward-xact))))

(std::leader-keybind "aL" #'std::ledger)

(std::after ledger-mode

  (std::keybind ledger-mode-map
    "M-J"   #'std::ledger::forward
    "M-K"   #'std::ledger::backward
    "M-q"   #'ledger-post-align-dwim
    [remap save-buffer] #'std::ledger::save)

  (std::mode-leader-keybind 'ledger-mode
    "C-w" #'std::ledger::finish
    "c"   #'std::ledger::goto-current-month
    "L"   #'std::ledger::parse-csv
    "s"   #'ledger-sort-buffer
    "S"   #'ledger-sort-region
    "o"   #'ledger-occur-mode
    "y"   #'ledger-copy-transaction-at-point
    "d"   #'ledger-delete-current-transaction
    "r"   #'ledger-report
    "R"   #'ledger-reconcile))

(std::after ledger-mode

  (defface std::ledger::month-face
    '((t (:foreground "#ccb18b" :bold t :height 1.1 :background "#333366" :box (:line-width -1 :color "#1a1a1a"))))
    ""
    :group 'std)

  (font-lock-add-keywords
   'ledger-mode
   `((,(rx (group-n
            1
            bol
            "+++ "
            (1+ (or alnum " "))
            " +++"
            "\n"))
      1 'std::ledger::month-face t))
   'prepend)

  (setq ledger-default-date-format           ledger-iso-date-format
        ledger-mode-should-check-version     nil
        ledger-post-amount-alignment-column  62
        ledger-post-account-alignment-column 2
        ledger-clear-whole-transactions      t
        company-backends-ledger-mode         '((company-capf company-dabbrev :with company-yasnippet)))

  (add-to-list 'ledger-report-format-specifiers
               (cons "current-year" (lambda () (format-time-string "%Y"))))
    (setf ledger-reports
        '(;;("bal" "%(binary) -f %(ledger-file) bal")
          ;;("reg" "%(binary) -f %(ledger-file) reg")
          ;;("payee" "%(binary) -f %(ledger-file) reg @%(payee)")
          ;;("account" "%(binary) -f %(ledger-file) reg %(account)")
          ("Register"
           "%(binary) reg %(account) --real")
          ("Jahresregister"
           "%(binary) reg %(account) --real -p %(current-year) ")
          ("Jahresbudget"
           "%(binary) bal -p \"this year\" /Budget/"))))

(defun std::mu4e::compose-hook ()
  (use-hard-newlines -1))

(std::autoload #'std::mu4e)
(add-hook 'mu4e-compose-mode-hook #'std::mu4e::compose-hook)

(std::after mu4e
  (defun std::mail::add-tag (&optional arg)
    (interactive "P")
    (-if-let (msg (mu4e-message-at-point :no-error))
        (-let [tags (if arg
                        "+todo"
                      (->> (read-string "Tag: ")
                           (s-split (rx (1+ " ")))
                           (--map (format "+%s" it))
                           (s-join ",")))]
          (mu4e-action-retag-message msg tags))
      (message "No message here")))

  (defun std::mail::remove-tag ()
    (interactive)
    (-if-let (msg (mu4e-message-at-point :no-error))
        (let* ((tags (mu4e-message-field msg :tags))
               (remove (if (>= 1 (length tags))
                           (format "-%s" (car tags))
                         (->> (completing-read "Tag: " tags)
                              (s-split (rx (1+ " ")))
                              (--map (format "-%s" it))
                              (s-join ",")))))
          (mu4e-action-retag-message msg remove))
      (message "No message here"))))

(std::after mu4e
  (defun std::mu4e::refresh (&optional arg)
    (interactive "P")
    (if (null arg)
        (mu4e-headers-rerun-search)
      (pfuture-callback ["mbsync" "-a"]
        :on-success
        (progn (mu4e-update-index)
               (mu4e-headers-rerun-search))
        :on-error (message "Mail Update failed: %s" (s-trim (pfuture-callback-output)))))))

(std::after mu4e

  (setq user-mail-address "alexanderm@web.de"
        user-full-name "Alexander Miller")

  (setq mu4e-confirm-quit                 nil
        mu4e-sent-messages-behavior       'delete
        mu4e-maildir                      (expand-file-name "~/.mail")
        mu4e-change-filenames-when-moving t
        mu4e-use-fancy-chars              nil
        mu4e-get-mail-command             "mbsync -a"
        mu4e-headers-draft-mark           '("D" . "⚒")
        mu4e-headers-flagged-mark         '("F" . "✚")
        mu4e-headers-new-mark             '("N" . "✱")
        mu4e-headers-passed-mark          '("P" . "❯")
        mu4e-headers-replied-mark         '("R" . "❮")
        mu4e-headers-seen-mark            '("S" . "✔")
        mu4e-headers-trashed-mark         '("T" . "⏚")
        mu4e-headers-attach-mark          '("a" . "📎")
        mu4e-headers-attach-mark          '("a" . "a")
        mu4e-headers-encrypted-mark       '("x" . "⚴")
        mu4e-headers-signed-mark          '("s" . "☡")
        mu4e-headers-unread-mark          '("u" . "⎕")
        mu4e-headers-fields               `((:date . 8)
                                            (:flags . 6)
                                            (:mailing-list . 10)
                                            (:from . 22)
                                            (:subject . ,(- (frame-width) (+ 8 6 10 22 8)))))

  (setq mu4e-bookmarks
        (list
         (make-mu4e-bookmark
          :name "Unread Messages"
          :query "flag:unread AND NOT flag:trashed"
          :key ?u)
         (make-mu4e-bookmark
          :name "Last 24 hours"
          :query "date:24h.."
          :key ?t)
         (make-mu4e-bookmark
          :name "Last 7 days"
          :query "date:7d..now"
          :key ?w)
         (make-mu4e-bookmark
          :name "Github Messages"
          :query "github"
          :key ?g)
         (make-mu4e-bookmark
          :name "Messages with images"
          :query "mime:image/*"
          :key ?p)))

  (setq mu4e-marks
        '((tag
           :char "t"
           :prompt "gtag"
           :ask-target
           (lambda nil (read-string "What tag do you want to add? "))
           :action
           (lambda (docid msg target) (mu4e-action-retag-message msg target)))

          (refile
           :char ("r" . "▶")
           :prompt "refile"
           :dyn-target
           (lambda (target msg) (mu4e-get-refile-folder msg))
           :action
           (lambda (docid msg target)
             (mu4e~proc-move docid (mu4e~mark-check-target target) "-N")))

          (delete
           :char ("D" . "❌ ")
           :prompt "Delete"
           :show-target (lambda (target) "delete")
           :action (lambda (docid msg target) (mu4e~proc-remove docid)))

          (flag
           :char ("+" . "⚑")
           :prompt "+flag"
           :show-target (lambda (target) "flag")
           :action
           (lambda (docid msg target)
             (mu4e~proc-move docid nil "+F-u-N")))

          (move
           :char ("m" . "▶")
           :prompt "move"
           :ask-target mu4e~mark-get-move-target
           :action (lambda (docid msg target)
                     (mu4e~proc-move docid
                                     (mu4e~mark-check-target target)
                                     "-N")))

          (read
           :char ("!" . "👁")
           :prompt "!read"
           :show-target (lambda (target) "read")
           :action (lambda (docid msg target)
                     (mu4e~proc-move docid nil "+S-u-N")))

          (trash
           :char ("d" . "🗑")
           :prompt "dtrash"
           :dyn-target (lambda (target msg)
                         (mu4e-get-trash-folder msg))
           :action (lambda (docid msg target)
                     (mu4e~proc-move docid
                                     (mu4e~mark-check-target target)
                                     "+T-N")))

          (unflag
           :char ("-" . "➖")
           :prompt "-unflag"
           :show-target (lambda (target) "unflag")
           :action (lambda (docid msg target)
                     (mu4e~proc-move docid nil "-F-N")))

          (untrash
           :char ("=" . "▲")
           :prompt "=untrash"
           :show-target (lambda (target) "untrash")
           :action (lambda (docid msg target)
                     (mu4e~proc-move docid nil "-T")))

          (unread
           :char "?"
           :prompt "?unread"
           :show-target (lambda (target) "unread")
           :action (lambda (docid msg target)
                     (mu4e~proc-move docid nil "-S+u-N")))

          (unmark
           :char " "
           :prompt "unmark"
           :action (mu4e-error "No action for unmarking"))

          (action
           :char ("a" . "◎")
           :prompt "action"
           :ask-target (lambda ()
                         (mu4e-read-option "Action: " mu4e-headers-actions))
           :action (lambda (docid msg actionfunc)
                     (save-excursion
                       (when (mu4e~headers-goto-docid docid)
                         (mu4e-headers-action actionfunc)))))

          (something
           :char ("*" . "✱")
           :prompt "*something"
           :action (mu4e-error "No action for deferred mark")))))

(std::after mu4e

  (defun mu4e~headers-line-apply-flag-face (msg line) line)

  (defun mu4e~headers-field-apply-basic-properties (msg field val width)
    (case field
      (:subject
       (propertize
        (concat
         (mu4e~headers-thread-prefix (mu4e-message-field msg :thread))
         (truncate-string-to-width val 600))
        'face
        (let ((flags (mu4e-message-field msg :flags)))
          (cond
           ((memq 'trashed flags) 'mu4e-trashed-face)
           ((memq 'draft flags) 'mu4e-draft-face)
           ((or (memq 'unread flags) (memq 'new flags))
            'mu4e-unread-face)
           ((memq 'flagged flags) 'mu4e-flagged-face)
           ((memq 'replied flags) 'mu4e-replied-face)
           ((memq 'passed flags) 'mu4e-forwarded-face)
           (t 'mu4e-header-face)))))
      (:thread-subject
       (propertize
        (mu4e~headers-thread-subject msg)
        'face 'font-lock-doc-face))
      ((:maildir :path :message-id)
       (propertize val 'face 'font-lock-keyword-face))
      ((:to :from :cc :bcc)
       (propertize
        (mu4e~headers-contact-str val)
        'face 'font-lock-variable-name-face))
      (:from-or-to (mu4e~headers-from-or-to msg))
      (:date
       (propertize
        (format-time-string mu4e-headers-date-format val)
        'face 'font-lock-string-face))
      (:mailing-list
       (propertize
        (mu4e~headers-mailing-list val)
        'face 'font-lock-builtin-face))
      (:human-date
       (propertize
        (mu4e~headers-human-date msg)
        'help-echo (format-time-string
                    mu4e-headers-long-date-format
                    (mu4e-msg-field msg :date))
        'face 'font-lock-string-face))
      (:flags
       (propertize (mu4e~headers-flags-str val)
                   'help-echo (format "%S" val)
                   'face 'font-lock-type-face))
      (:tags
       (propertize
        (mapconcat 'identity val ", ")
        'face 'font-lock-builtin-face))
      (:size (mu4e-display-size val))
      (t (mu4e~headers-custom-field msg field)))))

(std::leader-keybind
 "aM" #'std::mu4e)

(std::after mu4e

  (std::keybind mu4e-main-mode-map
    "u" #'mu4e-update-index)

  (std::keybind mu4e-headers-mode-map
    "+" #'std::mail::add-tag
    "-" #'std::mail::remove-tag)

  (std::evil-keybind evilified mu4e-headers-mode-map
    "gr" #'std::mu4e::refresh)

  (std::evil-keybind 'evilified (mu4e-headers-mode-map mu4e-view-mode-map mu4e-conversation-map)
    "J" #'std::evil::forward-five-lines
    "K" #'std::evil::backward-five-lines))

(std::add-hooks #'rainbow-mode
  (emacs-lisp-mode-hook
   conf-mode-hook
   help-mode-hook
   css-mode-hook))

(add-hook 'prog-mode-hook    #'rainbow-delimiters-mode-enable)
(add-hook 'snippet-mode-hook #'rainbow-delimiters-mode-disable)

(std::after elfeed
  (evil-define-state elfeed
    "Evil elfeed state."
    :cursor '(bar . 0)
    :enable (evilified)))

(std::after elfeed

  (defun std::elfeed::visit-entry-dwim (&optional arg)
    (interactive "P")
    (if arg
        (elfeed-search-browse-url)
      (-let [entry (if (eq major-mode 'elfeed-show-mode) elfeed-show-entry (elfeed-search-selected :single))]
        (if (s-matches? (rx "https://www.youtube.com/watch" (1+ any))
                        (elfeed-entry-link entry))
            (let* ((quality (completing-read "Max height resolution (0 for unlimited): " '("0" "480" "720" "1080")))
                   (arg (if (= 0 (string-to-number quality)) "" (std::fmt "--ytdl-format=[height<=?${quality}]"))))
              (message "Opening %s with height ≤ %s with mpv..."
                       (propertize (elfeed-entry-link entry) 'face 'font-lock-string-face)
                       (propertize quality 'face 'font-lock-keyword-face))
              (elfeed-untag entry 'unread)
              (start-process "elfeed-mpv" nil "mpv" arg (elfeed-entry-link entry))
              (elfeed-search-update :force))
          (if (eq major-mode 'elfeed-search-mode)
              (elfeed-search-browse-url)
            (elfeed-show-visit)))))))

(std::after elfeed
  (defun std::elfeed::ignore-entry ()
    (interactive)
    (-let [entries (elfeed-search-selected)]
      (elfeed-tag entries 'ignore)
      (mapc #'elfeed-search-update-entry entries)
      (elfeed-search-update :force))))

(std::autoload #'std::elfeed #'std::elfeed::mode-hook)
(add-hook 'elfeed-search-mode-hook #'std::elfeed::mode-hook)

(std::after elfeed
  (setf elfeed-db-directory  (std::fmt "${std::orgdir}/Elfeed-DB")
        elfeed-search-filter "@6-months-ago -ignore"
        elfeed-search-face-alist
        '((unread   elfeed-search-unread-title-face)
          (vids     font-lock-constant-face)
          (blog     font-lock-doc-face)
          (reddit   font-lock-variable-name-face)
          (webcomic font-lock-builtin-face))))

(std::leader-keybind
 "af" #'std::elfeed)

(std::after elfeed
  (std::keybind elfeed-search-mode-map
    "J" #'std::evil::forward-five-lines
    "K" #'std::evil::backward-five-lines
    "i" #'std::elfeed::ignore-entry
    [remap elfeed-search-browse-url] #'std::elfeed::visit-entry-dwim))

(add-hook 'text-mode-hook #'flyspell-mode)
(add-hook 'markdown-mode-hook #'flyspell-mode)
(add-hook 'org-mode-hook #'flyspell-mode-off)

(std::autoload #'std::swipe-symbol-at-point)

(std::after swiper
  (setf ivy-height       4
        ivy-height-alist '((swiper . 8)))

  (add-to-list 'swiper-font-lock-exclude 'org-mode)

  (std::if-version 26
    (setf ivy-posframe-display-functions-alist
          '((swiper          . ivy-posframe-display-at-frame-bottom-window-center)
            (complete-symbol . ivy-posframe-display-at-point)
            (counsel-M-x     . ivy-posframe-display-at-window-bottom-left)
            (t               . ivy-posframe-display)))
    (ivy-posframe-mode t)))

(std::global-keybind "C-s" #'swiper)

(std::keybind (evil-normal-state-map evil-insert-state-map evil-visual-state-map evil-motion-state-map)
  "C-M-s" #'std::swipe-symbol-at-point)

(std::autoload #'std::defun-query-replace)
(std::leader-keybind
 "üü" #'anzu-query-replace
 "üf" #'std::defun-query-replace)

(std::after anzu
  (setf anzu-cons-mode-line-p nil))

(defun std::yas::activate-fundamental-mode ()
  (yas-activate-extra-mode 'fundamental-mode))

(std::after yasnippet
  (setf yas-snippet-dirs (list (std::fmt "${std::spacemacsdir}/snippets"))))

(add-hook 'yas-minor-mode-hook #'std::yas::activate-fundamental-mode)

(std::after yasnippet
  (define-key evil-insert-state-map (kbd "C-l") #'yas-expand))

(add-hook 'snippet-mode-hook #'whitespace-mode)

(std::after conf-mode
  (require 'i3wm-config-mode))

(std::after writeroom-mode
  (defun std::writeroom::toggle-line-numbers ()
    (if writeroom-mode
        (display-line-numbers-mode -1)
      (display-line-numbers-mode t))))

(spacemacs|add-toggle writeroom
  :mode writeroom-mode
  :documentation "Disable visual distractions."
  :evil-leader "TW")

(std::after writeroom-mode
  (setq writeroom-width                120
        writeroom-extra-line-spacing   0
        writeroom-bottom-divider-width 0
        writeroom-global-effects
        (delete 'writeroom-set-fullscreen writeroom-global-effects))

  (add-hook 'writeroom-mode-hook #'std::writeroom::toggle-line-numbers))

(define-key evil-normal-state-map (kbd "zva") #'vimish-fold-avy)
(define-key evil-normal-state-map (kbd "zvd") #'vimish-fold-delete)
(define-key evil-normal-state-map (kbd "zvv") #'vimish-fold-toggle)
(define-key evil-normal-state-map (kbd "zvz") #'vimish-fold)

(std::global-keybind "C-x ß" #'helpful-at-point)

(add-hook 'helpful-mode-hook #'evil-motion-state)

(std::autoload #'std::eval-last-sexp)

(eros-mode t)

(std::global-keybind "C-x C-e" #'std::eval-last-sexp)
(std::mode-leader-keybind 'emacs-lisp-mode "ee" #'std::eval-last-sexp)

(defun std::multi-compile ()
  (interactive)
  (-let [default-directory
          (condition-case _
              (projectile-project-root)
            (error (--if-let (buffer-file-name)
                       (if (f-directory? it)
                           it
                         (f-parent it))
                     "~/")))]
    (call-interactively #'multi-compile-run)))

(std::leader-keybind "pc" #'std::multi-compile)

(std::after multi-compile
  (setq multi-compile-alist
        '((emacs-lisp-mode ("Test" . "make test")
                           ("Lint" . "make lint")
                           ("Compile" . "make compile")
                           ("Clean" . "make clean")))
        multi-compile-completion-system 'helm))

(std::after avy
  (setf avy-all-windows      nil
        avy-case-fold-search nil))

(std::evil-keybind (normal motion visual) global-map
  "M-o" #'evil-avy-goto-char-2)

(std::after make-mode

  (defun std::make::mode-hook ()
    (setf company-backends '((company-capf company-dabbrev-code :with company-yasnippet))))
  (add-hook 'makefile-mode-hook #'std::make::mode-hook))

(show-smartparens-global-mode t)

(require 'smartparens-config)

(std::add-hooks #'smartparens-mode
  (prog-mode-hook text-mode-hook comint-mode-hook))

(setq sp-show-pair-delay
      (or (bound-and-true-p sp-show-pair-delay) 0.2)
      sp-show-pair-from-inside t
      sp-cancel-autoskip-on-backward-movement nil
      sp-highlight-pair-overlay nil
      sp-highlight-wrap-overlay nil
      sp-highlight-wrap-tag-overlay nil)

(std::leader-keybind
 "kr" #'sp-raise-sexp
 "kw" #'sp-wrap-round
 "ks" #'sp-forward-slurp-sexp
 "kS" #'sp-backward-slurp-sexp
 "kb" #'sp-forward-barf-sexp
 "kB" #'sp-backward-barf-sexp
 "js" #'sp-split-sexp
 "jn" #'sp-newline)

(which-key-mode -1)

(std::leader-keybind
 "v" #'er/expand-region)

(std::after expand-region
  (setq expand-region-contract-fast-key "c"
        expand-region-reset-fast-key    "r"))

(std::autoload #'std::weather)
(std::leader-keybind "aW" #'std::weather)

(std::after wttrin
  (setq wttrin-default-cities '("Stuttgart")
        wttrin-default-accept-language '("en-gb")))

(defface std::modeline::selected-separator-face
  '((t (:background "#559955")))
  ""
  :group 'std)

(defface std::modeline::separator-inactive-face
  '((t (:background "#25252a")))
  ""
  :group 'std)

(defface std::modeline::num-face
  '((t (:foreground "#997799" :bold t)))
  ""
  :group 'std)

(defface std::modeline::num-inactive-face
  '((t (:foreground "#997799" :background "#25252a" :bold t)))
  ""
  :group 'std)

(defface std::modeline::major-mode-face
  '((t (:foreground "#997799" :bold t)))
  ""
  :group 'std)

(defface std::modeline::major-mode-inactive-face
  '((t (:foreground "#997799" :background "#25252a" :bold t)))
  ""
  :group 'std)

(defface std::modeline::buffer-id-inactive
  '((t (:foreground "#c98459" :background "#25252a" :bold t :box "#000000")))
  ""
  :group 'std)

(require 'inline)
(require 'doom-modeline)

(declare-function winum-get-number "winum")
(declare-function eyebrowse--get "eyebrowse")

(defconst std::modeline::selected-window-xpm
  (doom-modeline--make-xpm 'std::modeline::selected-separator-face 5 30))

(defconst std::modeline::unselected-window-xpm
  (doom-modeline--make-xpm 'std::modeline::separator-inactive-face 5 30))

(define-inline std::num-to-unicode (n)
  (inline-letevals (n)
    (inline-quote
     (pcase ,n
       (1 " ➊") (2 " ➋") (3 " ➌") (4 " ➍")  (5 " ➎") (6 " ➏")
       (7 " ➐") (8 " ➑") (9 " ➒") (10 " ➓") (_ "")))))

(doom-modeline-def-segment std::modeline::window-number
  (--when-let (winum-get-number)
    (propertize (std::num-to-unicode it)
                'face (if (doom-modeline--active)
                          'std::modeline::num-face
                        'std::modeline::num-inactive-face))))

(doom-modeline-def-segment std::modeline::desktop-number
  (propertize (std::num-to-unicode (eyebrowse--get 'current-slot))
              'face (if (doom-modeline--active)
                        'std::modeline::num-face
                      'std::modeline::num-inactive-face)))

(doom-modeline-def-segment std::modeline::buffer-id
  (propertize (concat " " (buffer-name))
              'face (if (doom-modeline--active)
                        'mode-line-buffer-id
                      'std::modeline::buffer-id-inactive)))

(doom-modeline-def-segment std::modeline::window-bar
  (if (doom-modeline--active)
      std::modeline::selected-window-xpm
    std::modeline::unselected-window-xpm))

(defconst std::modeline::major-mode-local-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line down-mouse-1]
      `(menu-item ,(purecopy "Menu Bar") ignore
                  :filter (lambda (_) (mouse-menu-major-mode-map))))
    (define-key map [mode-line mouse-2] 'describe-mode)
    (define-key map [mode-line down-mouse-3] mode-line-mode-menu)
    map))

(doom-modeline-def-segment std::modeline::major-mode
  (propertize (concat " " (format-mode-line mode-name))
              'mouse-face 'mode-line-highlight
              'local-map std::modeline::major-mode-local-map
              'face (if (doom-modeline--active)
                        'std::modeline::major-mode-face
                      'std::modeline::major-mode-inactive-face)))

(defconst std::modeline::flycheck-bullet-info  (propertize " • %s" 'face 'doom-modeline-info))
(defconst std::modeline::flycheck-bullet-warn  (propertize " • %s" 'face 'doom-modeline-warning))
(defconst std::modeline::flycheck-bullet-error (propertize " • %s" 'face 'doom-modeline-urgent))

(doom-modeline-def-segment std::modeline::flycheck
  (when (bound-and-true-p flycheck-mode)
    (with-no-warnings
      (let* ((count    (flycheck-count-errors flycheck-current-errors))
             (warnings (alist-get 'warning count))
             (errors   (alist-get 'error count)))
        (concat (when warnings (format std::modeline::flycheck-bullet-warn warnings))
                (when errors   (format std::modeline::flycheck-bullet-error errors)))))))

(doom-modeline-def-modeline 'std
  '(std::modeline::window-bar
    std::modeline::window-number
    std::modeline::desktop-number
    std::modeline::buffer-id
    std::modeline::major-mode
    std::modeline::flycheck))

(doom-modeline-set-modeline 'std :global-default)

(std::after magit

  (doom-modeline-def-segment std::modeline::buffer-process
    mode-line-process)

  (doom-modeline-def-modeline 'magit
    '(std::modeline::window-bar
      std::modeline::window-number
      std::modeline::desktop-number
      std::modeline::buffer-id
      std::modeline::major-mode
      std::modeline::buffer-process))

  (defun std::modeline::magit-modeline ()
    (doom-modeline-set-modeline 'magit nil))

  (add-hook 'magit-mode-hook #'std::modeline::magit-modeline))

(std::after treemacs

  (doom-modeline-def-modeline 'treemy
    '(std::modeline::window-bar
      std::modeline::desktop-number
      std::modeline::major-mode))

  (defun std::modeline::treemacs-modeline ()
    (doom-modeline-set-modeline 'treemy nil))

  (add-hook 'treemacs-mode-hook #'std::modeline::treemacs-modeline))

(std::after elfeed

  (doom-modeline-def-segment std::modeline::feeds
    (concat " " (elfeed-search--count-unread)))

  (doom-modeline-def-modeline 'elfeed
    '(std::modeline::window-bar
      std::modeline::desktop-number
      std::modeline::major-mode
      std::modeline::feeds))

  (defun std::modeline::elfeed ()
    (doom-modeline-set-modeline 'elfeed nil))

  (add-hook 'elfeed-search-mode-hook #'std::modeline::elfeed))

(std::idle 0.5 :no-repeat
  (dolist (buffer '("*Messages*" "*spacemacs*" "*Compile-Log*" "*scratch*"))
    (when (get-buffer buffer)
      (with-current-buffer buffer
        (setq-local mode-line-format (default-value 'mode-line-format))
        (doom-modeline-set-selected-window)))))

(cl-defun std::downscale (font &key char start end (size 12))
  (set-fontset-font "fontset-default" `(,(or start char) . ,(or end char))
                    (font-spec :size size :name font)))

(std::downscale "Font Awesome" :start #xf000 :end #xf2e0)

(std::downscale "Symbola" :char ?\⇛)
(std::downscale "Symbola" :char ?\⭢)
(std::downscale "Symbola" :char ?\⩵)
(std::downscale "Symbola" :char ?\⮕)
(std::downscale "Symbola" :char ?\⬅)
(std::downscale "Symbola" :char ?\◉)
(std::downscale "Symbola" :char ?\•)
(std::downscale "Symbola" :char ?\⏵)
(std::downscale "Symbola" :char ?\⏸)
(std::downscale "Symbola" :char ?\⏹)
(std::downscale "Symbola" :char ?\⏮)
(std::downscale "Symbola" :char ?\⏭)
(std::downscale "Symbola" :char ?\⏪)
(std::downscale "Symbola" :char ?\⏩)
(std::downscale "Symbola" :char ?\🔀)
(std::downscale "Symbola" :char ?\🔁)
(std::downscale "Symbola" :char ?\🔂)
(std::downscale "Symbola" :char ?\❯)
(std::downscale "Symbola" :char ?\✸)
(std::downscale "Symbola" :char ?\✿)
(std::downscale "Symbola" :char ?\✔)
(std::downscale "Symbola" :char ?\┣)
(std::downscale "Symbola" :char ?\▶)
(std::downscale "Symbola" :char ?\❌)
(std::downscale "Symbola" :char ?\⚑)
(std::downscale "Symbola" :char ?\▲)
(std::downscale "Symbola" :char ?\✱)
(std::downscale "Symbola" :char ?\📎 :size 9)
(std::downscale "Cantarell" :char ?\•)
(std::downscale "DejaVu Sans" :char ?\◎)
(std::downscale "DejaVu Sans" :char ?\⚓)
(std::downscale "DejaVu Sans" :char ?\◼ :size 10)
(std::downscale "DejaVu Sans" :char ?\❮ :size 10)
(std::downscale "DejaVu Sans" :char ?\▾ :size 14)
(std::downscale "DejaVu Sans" :char ?\▸ :size 14)
(std::downscale "DejaVu Sans" :char ?\▴ :size 14)
(std::downscale "DejaVu Sans" :char ?\◂ :size 14)
(std::downscale "DejaVu Sans" :char ?\↖ :size 10)
(std::downscale "DejaVu Sans" :char ?\↘ :size 10)
(std::downscale "DejaVu Sans" :char ?\↙ :size 10)
(std::downscale "DejaVu Sans" :char ?\↗ :size 10)
(std::downscale "DejaVu Sans" :char ?\∧ :size 14)
(std::downscale "DejaVu Sans" :char ?\∨ :size 14)
(std::downscale "DejaVu Sans" :char ?\➊ :size 14)
(std::downscale "DejaVu Sans" :char ?\➋ :size 14)
(std::downscale "DejaVu Sans" :char ?\➌ :size 14)
(std::downscale "DejaVu Sans" :char ?\➍ :size 14)
(std::downscale "DejaVu Sans" :char ?\➎ :size 14)
(std::downscale "DejaVu Sans" :char ?\➏ :size 14)
(std::downscale "DejaVu Sans" :char ?\➐ :size 14)
(std::downscale "DejaVu Sans" :char ?\➑ :size 14)
(std::downscale "DejaVu Sans" :char ?\➒ :size 14)
(std::downscale "DejaVu Sans" :char ?\➓ :size 14)

(std::keybind global-map
  "C-q" #'fill-region)

(std::leader-keybind "bs" #'std::scratch)

(setq display-line-numbers-widen       t
      display-line-numbers-width-start t
      display-line-numbers-grow-only   t)

(setq
  scroll-conservatively           20
  scroll-margin                   10
  scroll-preserve-screen-position t)

(add-hook 'before-save-hook #'delete-trailing-whitespace)

(global-subword-mode t)

(ido-mode -1)
(global-hl-line-mode -1)
(blink-cursor-mode -1)

(setq-default
 prettify-symbols-alist
 `(("lambda" . "λ")
   ("!="     . "≠")
   ("<-"     . "←")
   ("->"     . "→")))
(add-hook 'prog-mode-hook #'prettify-symbols-mode)

(setq-default
 safe-local-variable-values
 '((org-list-indent-offset . 1)
   (fill-column . 120)
   (eval auto-fill-mode t)))

(std::after pos-tip
  (setq pos-tip-background-color "#2d2d2d"
        pos-tip-foreground-color "#ccb18b"))

(setq custom-file (std::fmt "${std::spacemacsdir}/custom-file.el"))

(setq next-line-add-newlines t)

(setq-default truncate-lines t)

(setq tags-add-tables nil)

(setq-default indicate-empty-lines nil)

(setq load-prefer-newer t)

(setq-default tab-width 4)

(setq vc-follow-symlinks t)

(std::after dash
   (dash-enable-font-lock))

(setq browse-url-browser-function #'browse-url-firefox)

(defun spacemacs/title-prepare (&rest __args) "" "Emacs")

(setf gc-cons-threshold 10000000
      gc-cons-percentage 0.25)
(std::idle 2 :repeat #'garbage-collect)

(std::idle 0.1 :no-repeat
  (when (s-starts-with? "/tmp/" (-last-item command-line-args))
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (if (s-starts-with? "tmp" (buffer-name))
            (progn
              (switch-to-buffer buf)
              (setq-local mode-line-format (default-value 'mode-line-format)))
          (kill-buffer buf))))))
