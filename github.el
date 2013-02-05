;; github.el --- Interact with Github Issues through Emacs.

;; Maintainer: Abhi Yerra <abhi@berkeley.edu>
;; Author: Abhi Yerra <abhi@berkeley.edu>
;; Version: 0.1
;; Created: 23 May 2010
;; Keywords: github

;; This file is NOT part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 2, or (at your option) any later
;; version.
;;
;; This is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
;; for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING. If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
;; MA 02111-1307, USA.

(require 'json)

(defconst github-version "0.1"
  "Version of github.el")

(defcustom github-login ""
  "Login for github"
  :type 'string
  :group 'github)

(defcustom github-password ""
  "Password for github."
  :type 'string
  :group 'github)

;; The repos to autocomplete. Should be of the form username/repo.
;; Ex. "abhiyerra/txtdrop" "abhiyerra/vayu"
(defvar github-autocomplete-repos '())

(defun github-repo-complete ()
  (completing-read "Repository: "
                   github-autocomplete-repos
                   nil nil
                   "")) ;; (concat github-login "/"))) ;; default to loging to autocomplete


;; (defun github-repos ()
;;   "Reload all of user's repos"
;;   (interactive)
;;   (github-api-request "GET" (concat "repos/show/" github-login) ""))

;; (switch-to-buffer (github-api-request "GET" (concat "repos/show/" github-login) ""))


;; Display issues for repo.
;;  - [X] g = github.com (view on github.com)
;;  - [X] o - open create new issue 
;;  - [ ] r - Refresh issues
;;  - [ ] f - Close issue
;;  - [ ] l - Add label to issue
;;  - [ ] m - Add milestone?
;;  - [X] n/p = next/previous issue
;;  - [ ] c - Comment on issue
;;  - [X] q - Quit
;;  - [X] <RET> - View issue
(define-derived-mode github-issues-list-mode fundamental-mode
  "github-issues-list-mode"
  "Major mode for listing Github issues."
  (org-set-local
   'header-line-format
           (format "%-5s %-3s %-10s %-10s %-20s %-5s  %-20s Quit `q'. Open in Browser `o'"
                   "ID"
		   "Mil"
                   "User"
                   "Assignee"
                   "Created At"
                   "State"
                   "Title"))


   
  (define-key github-issues-list-mode-map "n" 'github-next-line)
  (define-key github-issues-list-mode-map "p" 'github-previous-line)
  (define-key github-issues-list-mode-map "o" 'github-issues-new)
  (define-key github-issues-list-mode-map "q" 'github-issues-list-close)
  (define-key github-issues-list-mode-map "g" 'github-issues-list-open)
  (define-key github-issues-list-mode-map "\r" 'github-issues-show)) ;;  (define-key github-issues-list-mode-map "\r" 'github-issues-list-open))

(define-derived-mode github-issue-mode fundamental-mode
  "github-issues-list-mode"
  "Major mode for listing Github issues."
  (define-key github-issue-mode-map "g" 'github-issues-list-open)
  (define-key github-issue-mode-map "q" 'github-issue-close)
  )

(defun github-next-line()
  (interactive)
  (next-line)
  (save-selected-window
    (github-issues-show)))

(defun github-previous-line()
  (interactive)
  (previous-line)
  (save-selected-window
  (github-issues-show)))

(defun github-issues-list-close ()
  "Close the window."
  (interactive)
  (kill-buffer))

(defun github-issue-close ()
  "Close the window."
  (interactive)
  (quit-window t))


(defun github-issues-list-open ()
  "Close the window."
  (interactive)
  (browse-url (plist-get (get-text-property (point) 'issue) :html_url)))


(defun github-issues-list ()
  "List all the issues for a repository"
  (interactive)
  (let ((repo (github-repo-complete)))
    (let ((buf (get-buffer-create ; TODO This can probably be made simpler.
		(concat "*" repo " Issues*"))))
      (switch-to-buffer buf)
      (github-issues-list-mode)
      (setq buffer-read-only nil) 
      (erase-buffer)
      (let ((pg 1)
	    (maxpg 10) ;; just set artibrary limit of 10 (i.e. 1000 issues)
	    issues)
	(while (and (< pg (+ maxpg 1)) 
		    (> (length (setq issues (github-grab-issues repo pg))) 0)) 
	  (mapcar 'github--insert-issue-row issues)
	  (if (< (length issues) 100)
	      (setq pg (+ maxpg 1)) ;; hack to avoid extra unnecessary fetch
	    (setq pg (+ pg 1))))))
    (goto-char (point-min))
    (setq buffer-read-only t)
    (buffer-disable-undo)))

(defun github--insert-issue-row (issue)
  (let ((cur-line-start (point)))
    (insert
     (format "%-5s %-3s %-10s %-10s %-20s %-5s  %-15s"
              (plist-get issue :number)
	      (let ((milestone (plist-get (plist-get issue :milestone) :number)))
		(if milestone milestone ""))
	      (let ((login (plist-get (plist-get issue :user) :login)))
		(substring login 0 (min 10 (length login))))
              (let ((assignee (plist-get (plist-get issue :assignee) :login)))
		(let ((assignee (if assignee assignee "")))
		  (substring assignee 0 (min 10 (length assignee)))))
              (plist-get issue :created_at)
              (plist-get issue :state)
	      (let ((title (plist-get issue :title)))
		(substring title 0 (min (- (window-width) 5 1 3 1 10 1 10 1 20 1 5 2 1) (length title))))))
    (let ((cur-line-end (point)))
      (add-text-properties cur-line-start cur-line-end
                           `(issue ,issue)))
    (insert "\n")))


;; user, title, comments, labels created_at
(defun github-grab-issues (repo page)
  "Display the results for the repo."
  (save-excursion
    (switch-to-buffer (github-api-request "GET" (concat "repos/" repo "/issues?page=" (number-to-string page) "&per_page=100") ""))
    (goto-char (point-min))
    (re-search-forward "^\n")
    (beginning-of-line)
    (let ((response-string (buffer-substring (point) (buffer-end 1)))
          (json-object-type 'plist))
      (kill-buffer)
      (json-read-from-string response-string))))



;; Show an issue
;; - c - Add a comment
;; - d - Close issue
;; - e - Edit the issue
;; - l - Add label
(defun github-issues-show ()
  "Show a particular issue"
  (interactive)
  (let ((issue (get-text-property (point) 'issue)))
    (let ((buf (get-buffer-create (concat "*Issue*")))
	  (body (plist-get issue :body))
	  (title (plist-get issue :title)))
      (pop-to-buffer buf)
      (github-issue-mode)
      (setq buffer-read-only nil) 
      (let ((cur-line-start (point)))
	(erase-buffer)
	(insert (number-to-string (plist-get issue :number)) " " title "\n")
	(insert "Author: " (plist-get (plist-get issue :user) :login) "\n")
	(insert "Assignee: " (let ((assignee (plist-get (plist-get issue :assignee) :login)))
			       (if assignee assignee "(none)")) "\n")
	(insert "Comments: " (number-to-string (plist-get issue :comments)) "\n")
	(insert "\n")
	(insert (replace-regexp-in-string "[\r]*" "" body))
	(let ((cur-line-end (point)))
	  (add-text-properties cur-line-start cur-line-end
			       `(issue ,issue))))
      
      (setq buffer-read-only t)
      (goto-char (point-min)))))



;; Create new issues

;; TODO: Should be based on markdown-mode
(define-derived-mode github-issues-new-mode fundamental-mode
  "github-issues-new-mode"
  "Major mode for entering new Github issues."
  (org-set-local
   'header-line-format
   "Create Issue (first line=title). Finish `C-c C-c', abort `C-c C-k'.")
  ;; http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
  ;; Make sure messages are Github friendly
  (set-fill-column 72)
  (auto-fill-mode 1)
  (define-key github-issues-new-mode-map "\C-c\C-c" 'github-issues-new-create)
  (define-key github-issues-new-mode-map "\C-c\C-k" 'github-issues-new-cancel))

;; Display a new buffer to enter ticket.
(defun github-issues-new ()
  "Open a window to enter a new issue."
  (interactive)
  (save-excursion
    (let ((buf (get-buffer-create "*New Github Issue*")))
      (with-current-buffer buf
        (switch-to-buffer buf)
        (github-issues-new-mode)))))



;; From http://xahlee.blogspot.com/2011/09/emacs-lisp-function-to-trim-string.html
(defun trim-string (string)
  "Remove white spaces in beginning and ending of STRING.
White space here is any of: space, tab, emacs newline (line feed, ASCII 10)."
  (replace-regexp-in-string "\\`[ \t\n]*" "" (replace-regexp-in-string "[ \t\n]*\\'" "" string)))


;; The first line is the title, everything else is the body.
(defun github-issues-new-create ()
  "Create the issue on github."
  (interactive)
  (goto-char (point-min))
  (github-api-request
   "POST"
   (concat "repos/" (github-repo-complete) "/issues")
   (json-encode `(:title ,(buffer-substring-no-properties (point-min) (line-end-position))
		  :body ,(trim-string (buffer-substring-no-properties (line-end-position) (buffer-end 1))))))
  (kill-buffer))

(defun github-issues-new-cancel ()
  "Cancel the creation of the the issue."
  (interactive)
  (kill-buffer))


;; The main way to make a request to github.
(defun github-api-request (method url params)
  "Make a call to github"
  (let ((url-request-method method)
        (url-request-extra-headers
         `(("Content-Type" . "application/x-www-form-urlencoded")
           ("Authorization" . ,(concat "Basic "
                                       (base64-encode-string
                                        (concat github-login ":" github-password))))))
        (url-request-data params))
    (url-retrieve-synchronously
     (concat "https://api.github.com/" url))))

(defalias 'gissues 'github-issues-list)

(provide 'gissues)
