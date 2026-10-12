;;; .dir-locals.el --- Petring project-local variables -*- lexical-binding: t; -*-
((prog-mode . ((indent-tabs-mode . nil)))
 (sh-mode . ((sh-basic-offset . 2)))
 (erlang-mode
  . ((erlang-indent-level . 2)
     (eval
      . (progn
          (unless (fboundp 'petring--erlang-record-indent)
            (defun petring--record-context ()
              "Return `close', `field', or nil for the current line."
              (save-excursion
                (beginning-of-line)
                (let ((bol (point))
                      (close (looking-at "[ \t]*})[ \t]*\\.")))
                  (when (re-search-backward "^[ \t]*-record\\b" nil t)
                    (if (save-excursion
                          (goto-char (match-beginning 0))
                          (re-search-forward ")[ \t]*\\." bol t))
                        nil
                      (if close 'close 'field))))))
            (defun petring--erlang-record-indent (orig)
              "Indent record fields by `erlang-indent-level'; delegate otherwise."
              (let ((ctx (and (not (save-excursion
                                     (beginning-of-line)
                                     (looking-at "[ \t]*-record\\b")))
                              (petring--record-context))))
                (cond
                 ((eq ctx 'close)
                  (let ((old (current-indentation)))
                    (indent-line-to 0)
                    (- old)))
                 ((eq ctx 'field)
                  (let ((old (current-indentation)))
                    (indent-line-to erlang-indent-level)
                    (- erlang-indent-level old)))
                 (t (funcall orig)))))
            (defun petring-erlang-indent-region (beg end)
              "Indent region using petring's per-line rules."
              (save-excursion
                (goto-char beg)
                (while (< (point) end)
                  (erlang-indent-line)
                  (forward-line 1))))
            (advice-add 'erlang-indent-line :around #'petring--erlang-record-indent))
          (setq-local indent-region-function #'petring-erlang-indent-region)))))
 (erlang-ts-mode . ((erlang-indent-level . 2)))
 (web-mode . ((web-mode-code-indent-offset . 2)
              (web-mode-markup-indent-offset . 2)
              (web-mode-css-indent-offset . 2)
              (web-mode-sql-indent-offset . 2)))
 (conf-mode . ((tab-width . 2)))
 (yaml-ts-mode . ((tab-width . 2))))
