;;; ebib-reading-list.el --- Part of Ebib, a BibTeX database manager  -*- lexical-binding: t -*-

;; Copyright (c) 2003-2016 Joost Kremers
;; All rights reserved.

;; Author: Joost Kremers <joostkremers@fastmail.fm>
;; Maintainer: Joost Kremers <joostkremers@fastmail.fm>
;; Created: 2016
;; Version: 2.6
;; Keywords: text bibtex
;; Package-Requires: ((dash "2.5.0") (emacs "24.3"))

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions
;; are met:
;;
;; 1. Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 2. Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;; 3. The name of the author may not be used to endorse or promote products
;;    derived from this software without specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
;; IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
;; OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
;; IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
;; INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
;; NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES ; LOSS OF USE,
;; DATA, OR PROFITS ; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
;; THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;;; Commentary:

;; This file is part of Ebib, a BibTeX database manager for Emacs.  It contains
;; the code for managing the reading list.

;;; Code:

(require 'ebib-utils)

(defgroup ebib-reading-list nil "Settings for the reading list." :group 'ebib)

(defcustom ebib-reading-list-symbol "R"
  "Symbol used to indicate that the current entry is on the reading list.
If the entry is on the reading list, this symbol is displayed in
the mode line of the entry buffer after the entry key."
  :group 'ebib-reading-list
  :type '(string :tag "Reading list symbol"))

(defcustom ebib-reading-list-file nil
  "File for storing the reading list."
  :group 'ebib-reading-list
  :type '(choice (const :tag "No reading list")
                 (file :tag "Reading list file")))

(defcustom ebib-reading-list-template "* %M %T\n:PROPERTIES:\n%K\n:END:\n%F\n"
  "Template for an entry in the reading list.
New entries are created on the basis of this template, which should
contain the following directives:

%M : the TODO marker
%T : the title of the entry
%K : the unique identifier of the note
%F : the file path to the file to read.

The identifier is created on the basis of the entry key using the
function in the option `ebib-reading-list-identifier-function'.
The %T directive is replaced with the title of the item, which is
created using the function in `ebib-reading-list-title-function'.
The %F directive is replaced with a link to the file associated
with the item, which is created using the function in
`ebib-reading-list-file-link-function'.  The TODO marker is a
string indicating that the item is still on the todo list.  It is
set with the option `ebib-reading-list-todo-marker'."
  :group 'ebib-reading-list
  :type '(string "Reading list item template"))

(defcustom ebib-reading-list-title-function 'ebib-create-org-title
  "Function to create the title for a reading list entry.
This function is used to fill the %T directive in
`ebib-reading-list-template'.  It should take one argument, the
key of the entry for which a title is to be created."
  :group 'ebib-reading-list
  :type 'function)

(defcustom ebib-reading-list-identifier-function 'ebib-create-org-identifier
  "Function to create the identifier of a reading list item.
This function should take the key of the entry as argument and
should return a string that uniquely identifies the entry in the
notes file.  Note that the string \"reading_\" is prefixed to the
key before this function is called, in order to distinguish it
from the identifier used in notes files (see the option
`ebib-notes-identifier-function'."
  :group 'ebib-reading-list
  :type 'function)

(defcustom ebib-reading-list-link-function 'ebib-create-org-link
  "Function to create a link in a reading list item.
This function should take one argument, the key of the relevant
entry."
  :group 'ebib-reading-list
  :type 'function)

(defcustom ebib-reading-list-todo-marker "TODO"
  "Marker for reading list items that are still open."
  :group 'ebib-reading-list
  :type '(string :tag "Todo marker"))

(defcustom ebib-reading-list-done-marker "DONE"
  "Marker for reading list items that are done."
  :group 'ebib-reading-list
  :type '(string :tag "Done marker"))

(defcustom ebib-reading-list-remove-item-function 'ebib-reading-list-mark-item-as-done
  "Function to run when removing an item from the reading list.
This function is run with point positioned after the item's
identifier.  The default value removes the current orgmode
subtree, but if your reading list is not an org file, you may
want to set another function here."
  :group 'ebib-reading-list
  :type 'function)

(defun ebib-reading-list-mark-item-as-done ()
  "Mark the current reading list item as done."
  (org-todo ebib-reading-list-done-marker))

(defcustom ebib-reading-list-item-active-function 'ebib-reading-list-item-org-active-p
  "Function to determine whether a reading list item is done.
This function is called with point inside the item, at the end of
the item's identifier.  It should return non-nil when the item is
done, nil if it is still open."
  :group 'ebib-reading-list
  :type 'function)

(defun ebib-reading-list-item-org-active-p ()
  "Return t if point is in a reading list item that is done."
  (string= (org-get-todo-state) ebib-reading-list-todo-marker))

(defcustom ebib-reading-list-new-item-hook nil
  "Hook run when a new reading list item is created.
The functions in this hook can use the variable `ebib--cur-db' to
access the current database, the function `ebib--cur-entry-key'
to obtain the key of the current entry, and the database
functions, especially `ebib-db-get-field-value' and
`ebib-db-get-entry', to access the current entry's data
fields."
  :group 'ebib-reading-list
  :type 'hook)

(defcustom ebib-reading-list-remove-item-hook nil
  "Hook run when an item is removed from the reading list.
The functions in this hook can use the variable `ebib--cur-db' to
access the current database, the function `ebib--cur-entry-key'
to obtain the key of the current entry, and the database
functions, especially `ebib-db-get-field-value' and
`ebib-db-get-entry', to access the current entry's data fields."
  :group 'ebib-reading-list
  :type 'hook)

(defun ebib--reading-list-buffer ()
  "Return the buffer containing the reading list.
If the file has not been opened yet, open it, creating it if
necessary.  An error is raised if the location for the reading
list file is not accessible to the user."
  (unless ebib-reading-list-file
    (error "[Ebib] No reading list file defined"))
  (unless (file-writable-p ebib-reading-list-file)
    (error "[Ebib] Cannot read or create reading list file"))
  (find-file-noselect ebib-reading-list-file))

(defun ebib--reading-list-item-p (key)
  "Return t if KEY is on the reading list."
  (if (and ebib-reading-list-file
           (file-writable-p ebib-reading-list-file))
      (with-current-buffer (ebib--reading-list-buffer)
        (if (ebib--reading-list-locate-item key)
            (funcall ebib-reading-list-item-active-function)))))

(defun ebib--reading-list-locate-item (key)
  "Return the location of the reading list item for KEY.
Specifically, the location of the final character of the
identifier is returned.  If there is no item for KEY, the return
value is nil.  Note that this function searches in the current
buffer."
  (save-excursion
    (goto-char (point-min))
    (search-forward (funcall ebib-reading-list-identifier-function (concat "reading_" key)) nil t)))

(defun ebib--reading-list-new-item (key)
  "Add a reading list item for KEY.
Return KEY.  If there is already an item for KEY, do nothing and
return nil."
  (with-current-buffer (ebib--reading-list-buffer)
    (unless (ebib--reading-list-locate-item key)
      (goto-char (point-max))
      (insert (ebib--reading-list-fill-template key))
      (save-buffer)
      key)))

(defun ebib--reading-list-remove-item (key)
  "Remove the reading list item for KEY.
Return KEY if the item was removed.  If there is no item for KEY,
do nothing and return nil."
  (with-current-buffer (ebib--reading-list-buffer)
    (when (ebib--reading-list-locate-item key)
      (funcall ebib-reading-list-remove-item-function)
      (save-buffer)
      key)))

(defun ebib--reading-list-fill-template (key)
  "Create the text for a reading list item for KEY."
  (format-spec ebib-reading-list-template
               `((?K . ,(funcall ebib-reading-list-identifier-function (concat "reading_" key)))
                 (?T . ,(funcall ebib-reading-list-title-function key))
                 (?M . ,ebib-reading-list-todo-marker)
                 (?F . ,(funcall ebib-reading-list-link-function key)))))

(provide 'ebib-reading-list)

;;; ebib-reading-list.el ends here
