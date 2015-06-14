;;; flycheck-clangcheck.el --- A Flycheck checker difinition for ClangCheck.

;; Author: kumar8600 <kumar8600@gmail.com>
;; URL: https://github.com/kumar8600/flycheck-clangcheck
;; Version: 0.21
;; Package-Requires: ((cl-lib "0.5") (flycheck "0.17"))
		   
;; Copyright (c) 2015 by kumar8600 <kumar8600@gmail.com>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
a build directory where `compile_commands.json' exists."
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
