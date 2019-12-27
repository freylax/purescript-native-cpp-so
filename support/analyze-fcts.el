(defun find-psc-fcts ()
  (interactive ())
  (goto-char (point-min))
  (when (re-search-forward "#define +PS(N) +\\([a-z0-9_]+\\) +## +N" nil t 1)
    (let ((ns (match-string 1))
	  (fcts ()))
      (while (re-search-forward "auto +PS( *\\([a-z0-9_]+\\) *)() *->" nil t 1)
	(setq fcts (append fcts (list (concat ns (match-string 1)))))
	)
      (goto-char (point-min))
      fcts
      )
    )
  )

(defun find-ffi-fcts ()
  (interactive ())
  (goto-char (point-min))
  (let ((fcts ()))
    (while (re-search-forward "extern +\"C\" +auto +\\(PS_[a-z0-9_]+\\)() *->" nil t 1)
      (setq fcts (append fcts (list (match-string 1))))
      )
    (goto-char (point-min))
    fcts
    )
  )

(defun find-decl-fcts ()
  (interactive ())
  (goto-char (point-min))
  (let ((fcts ()))
    (while (re-search-forward "auto +\\(PS_[a-z0-9_]+\\)() *->" nil t 1)
      (setq fcts (append fcts (list (match-string 1))))
      )
    (goto-char (point-min))
    fcts
    )
  )


(defun analyze-fcts (basedir)
  (interactive "D")
  (let ((psc-src-dir (concat basedir "/output/src"))
	(ffi-dir (concat basedir "/ffi"))
	(decl ()) (unimpl ())
	(psc-impl ()) (psc-undecl ())
	(ffi-impl ()) (ffi-undecl ()))
    (dolist ( f (directory-files-recursively psc-src-dir "[a-z_-]+\\.h"))
      (find-file f)      
      (setq decl (append decl (find-decl-fcts))) 
      (kill-buffer)
      )
    (dolist ( f (directory-files-recursively psc-src-dir "[a-z_-]+\\.cpp"))
      (find-file f)
      (setq psc-impl (append psc-impl (find-psc-fcts)))
      (kill-buffer)
      )
    (dolist ( f (directory-files-recursively ffi-dir "[a-z_-]+\\.cpp"))
      (find-file f)
      (setq ffi-impl (append ffi-impl (find-ffi-fcts)))
      (kill-buffer)
      )
    (setq decl (sort decl 'string<))
    (setq psc-impl (sort psc-impl 'string<))
    (setq ffi-impl (sort ffi-impl 'string<))
    (setq unimpl (seq-difference decl (append psc-impl ffi-impl)))
    (setq psc-undecl (seq-difference psc-impl decl))
    (setq ffi-undecl (seq-difference ffi-impl decl))
    (setq unimpl (sort unimpl 'string<))
    (setq psc-undecl (sort psc-undecl 'string<))
    (setq ffi-undecl (sort ffi-undecl 'string<))
    (message "declared: %d, psc-impl: %d, ffi-impl: %d"
	     (length decl) (length psc-impl) (length ffi-impl))
    (message "unimpl: %d, psc-undecl: %d, ffi-undecl: %d"
	     (length unimpl) (length psc-undecl) (length ffi-undecl))
    (message "unimplemented functions:")
    (dolist (s unimpl) (message "%s" s) )
    (message "psc undeclared functions:")
    (dolist (s psc-undecl) (message "%s" s) )
    (message "ffi undeclared functions:")
    (dolist (s ffi-undecl) (message "%s" s) )    
    )
  )
      
