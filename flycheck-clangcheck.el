;;; flycheck-clangcheck.el --- Flycheck checker difinition for ClangCheck.

;; Author: kumar8600 <kumar8600@gmail.com>
;; URL: https://github.com/kumar8600/flycheck-clangcheck
;; Version: 0.11
;; Package-Requires: ((cl-lib "0.5") (json "1.3") (flycheck "0.17"))
		   
;; Copyright (c) 2014 by kumar8600
;; All rights reserved.

;; Redistribution and use in source and binary forms, with or without modification,
;; are permitted provided that the following conditions are met:

;; * Redistributions of source code must retain the above copyright notice, this
;;   list of conditions and the following disclaimer.

;; * Redistributions in binary form must reproduce the above copyright notice, this
;;   list of conditions and the following disclaimer in the documentation and/or
;;   other materials provided with the distribution.

;; * Neither the name of the kumar8600 nor the names of its
;;   contributors may be used to endorse or promote products derived from
;;   this software without specific prior written permission.

;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
;; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
;; ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
;; ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'flycheck)

(flycheck-def-option-var flycheck-clangcheck-analyze nil c/c++-clangcheck
  "Whether to enable Static Analysis to C/C++ in ClangCheck.

When non-nil, enable Static Analysis to C/C++ via `-analyze'."
  :type 'boolean
  :safe #'booleanp)

(flycheck-def-option-var flycheck-clangcheck-extra-arg nil c/c++-clangcheck
  "Additional argument to append to the compiler command line for ClangCheck.

The value of this variable is a list of strings, where each
string is an additional argument to pass to ClangCheck, via
the `-extra-arg' option."
  :type '(repeat (string :tag "Argument"))
  :safe #'flycheck-string-list-p)

(flycheck-def-option-var flycheck-clangcheck-extra-arg-before nil c/c++-clangcheck
  "Additional argument to prepend to the compiler command line for ClangCheck.

The value of this variable is a list of strings, where each
string is an additional argument to prepend to the compiler
command line to pass to ClangCheck, via the
`-extra-arg-before' option."
  :type '(repeat (string :tag "Prepend argument"))
  :safe #'flycheck-string-list-p)

(flycheck-def-option-var flycheck-clangcheck-fatal-assembler-warnings nil c/c++-clangcheck
  "Whether to enable Considering warning as error to C/C++ in ClangCheck.

When non-nil, enable Considering warning as error to ClangCheck via
`-fatal-assembler-warnings'."
  :type 'boolean
  :safe #'booleanp)

(flycheck-def-option-var flycheck-clangcheck-build-path nil c/c++-clangcheck
  "Build directory for ClangCheck.

The value of this variable is a string, describing
build directory `compile_commands.json' exists to ClangCheck via `-p'."
  :type '(directory :tag "Build directory")
  :safe #'stringp)

(defun flycheck-clangcheck-get-compile-command (build-dir source)
  "Get a list of compile commands from `compile_commands.json' at BUILD-DIR for SOURCE."
  (let ((commands (json-read-file (expand-file-name "compile_commands.json"
						    build-dir)))
	(source-truename (file-truename source)))
    (let ((found (cl-find-if (lambda (item)
			       (string= source-truename
					(file-truename (cdr (assq 'file item)))))
			     commands)))
      (if found
	  (split-string-and-unquote (cdr (assq 'command found)))
	nil))))

(flycheck-define-checker c/c++-clangcheck
  "A C/C++ syntax checker using ClangCheck.

See URL `http://clang.llvm.org/docs/ClangCheck.html'."
  :command ("clang-check"
	    (option-flag "-analyze" flycheck-clangcheck-analyze)
	    (option-flag "-fatal-assembler-warnings" flycheck-clangcheck-fatal-assembler-warnings)
	    (option-list "-extra-arg=" flycheck-clangcheck-extra-arg s-prepend)
	    (option-list "-extra-arg-before=" flycheck-clangcheck-extra-arg-before s-prepend)
	    (option      "-p=" flycheck-clangcheck-build-path)
	    ;; We must stay in the same directory, to properly resolve #include
	    ;; with quotes
	    source-inplace
	    "--"
	    ;; To get works well with `source-inplace', build-directory's
	    ;; `compile_commands.json' parsing is done by own logic.
	    (eval
	     (or (and flycheck-clangcheck-build-path
		      (or (flycheck-clangcheck-get-compile-command flycheck-clangcheck-build-path
								   (buffer-file-name))
			  (progn (message "Build directory is set, but not found compile command from `compile_commands.json'.")
				 nil)))
		 (concat "-x"
			 (cl-case major-mode
			   (c++-mode "c++")
			   (c-mode "c")))))
	    "-fno-color-diagnostics"    ; Do not include color codes in output
	    "-fno-caret-diagnostics"    ; Do not visually indicate the source
					; location
	    "-fno-diagnostics-show-option") ; Do not show the corresponding
   					      ; warning group
  :error-patterns
  ((info line-start (file-name) ":" line ":" column
	 ": note: " (message) line-end)
   (warning line-start (file-name) ":" line ":" column
	    ": warning: " (message) line-end)
   (error line-start (file-name) ":" line ":" column
	  ": " (or "fatal error" "error") ": " (message) line-end))
  :modes (c-mode c++-mode))

(add-to-list 'flycheck-checkers 'c/c++-clangcheck)

(provide 'flycheck-clangcheck)

;;; flycheck-clangcheck.el ends here
