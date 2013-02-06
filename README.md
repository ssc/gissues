# Description

A way to interact with Github Issues through Emacs (think github-issues-mode).

# Config

    (load "~/path/to/gissues/github.el")
    (require 'gissues)

    (setq github-login "abhiyerra")
    ;; Enter your github password.
    (setq github-password "Password")
    ;; The repos that you want to have autocompleted
    (setq github-autocomplete-repos
          '("abhiyerra/txtdrop"
            "abhiyerra/rutt"
            "abhiyerra/Ravana"))

# Help

 - M-x gissues - List issues for a repository
 - M-x gissues-new - Create a new issue