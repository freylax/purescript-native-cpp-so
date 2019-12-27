;; This file contains the function
;; convert-ffi-module which adapts the
;; the existing ffi interface to the "extern C"
;; interface
;; use convert-ffi-dir to traverse a directory tree
;; with the sources


(defun convert-ffi-module ()
  (interactive ())
  (let ((matches 0)
	(module ""))
    (goto-char (point-min))
    (when (re-search-forward "FOREIGN_BEGIN( +\\([a-z_]+\\) +)" nil t 1)
      (let ((ns (match-string 1)))
	(setq module ns)
	(replace-match "using namespace purescript;")
	(while (re-search-forward "exports\\[\"\\([a-zA-Z0-9_]+\\)\\('*\\)\"\\]"
				  nil t 1)
	  (let ((fn (match-string 1))
		(start (car (match-data t))))
	    (replace-match
	     (concat "extern \"C\" auto PS_" ns "_" fn
		     (if (match-string 2)
			 (let ((i (length (match-string 2)))
			       (s "")
			       )
			   (while (> i 0)
			     (setq i (1- i))
			     (setq s (concat s "Prime_"))
			     )
			   s
			   )
		       )
		     "() -> const boxed& {\n"
		     "static const boxed _"))
	    (when (re-search-forward "\\({\\)\\|\\(;[ ]*//.*\\)\\|\\(;\\)" nil t 1)
	      (cond ((match-beginning 1) ;; matching a {} block
		     (goto-char (match-beginning 1))
		     (forward-list)
		     (search-forward ";"))
		    ((match-beginning 2) ;; matching a statement
		     (goto-char (match-end 2)))
		    ((match-beginning 3) ;; matching a statement with comment
		     (goto-char (match-end 3)))
		    )
	      (insert "\n return _;\n };")
	      (indent-region start (point))
	      (setq matches (1+ matches))
	      )
	    )
	  )
	)
      )
    (when (re-search-forward "FOREIGN_END" nil t)
      (replace-match ""))
    (goto-char (point-min))
    (message "%s:%d" module matches)
    matches
    )
  )

(defun convert-ffi-dir (dir)
  (interactive "D")
  (dolist ( file (directory-files-recursively dir "[a-z_-]+\\.cpp"))
    (message "opening:%s" file)
    (find-file file)
    (if (< 0 (convert-ffi-module))
	(save-buffer 0)
      )
    (kill-buffer)
    )
  )

