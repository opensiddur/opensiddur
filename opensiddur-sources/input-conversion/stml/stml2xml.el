;;; stml2xml --- convert STML markup to XML

;; Copyright 2010 Ze'ev Clementson

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Lesser General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU Lesser General Public License for more details.

;; You should have received a copy of the GNU Lesser General Public
;; License along with this program. If not, see http://www.gnu.org/licenses/

;;; Commentary:

;; Convert STML markup (defined for files created by The Internet Sacred Text
;; Archive) into XML.
;; See: http://www.jimblog.net/wp-content/uploads/sacredtexts/volun.htm
;; for an explanation of STML tags and macros.

;;; Code:

(defun spb2xml ()
  "Convert Singer's 'Standard Prayer Book' Siddur STML markup to XML.
Processes and saves the current buffer, so you will need to make a copy of
the input file if you don't want it overwritten."
  (interactive)
  
  ;; Insert XML declarations
  (goto-char (point-min))
  (insert "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
  (insert "<!DOCTYPE book [\n")
  (insert "<!ENTITY eacute \"&#233;\">\n")
  (insert "<!ENTITY nbsp \"&#160;\">\n")
  (insert "<!ENTITY quot \"&#34;\">\n")
  (insert "<!ENTITY sect \"&#167;\">\n")
  (insert "]>\n")

  ;; One-off replacements of HTML tags and tidy-ups
  (let ((start (point)))
	(search-forward "</head>")
	(delete-region start (point)))
  (while (re-search-forward "body>" nil t)
	(replace-match "book>"))
  (while (re-search-forward "</html>" nil t)
	(replace-match ""))
  (goto-char (point-min))
  (while (re-search-forward "align=\"center\" align=\"center\"" nil t)
	(replace-match "align=\"center\""))
		  
  ;; Global replacements
  (goto-char (point-min))
  (while (re-search-forward "<h" nil t)
	(replace-match "<title titlelevel=\"")
	(forward-char 1)
	(insert "\""))
  (goto-char (point-min))
  (while (re-search-forward "</h.>" nil t)
	(replace-match "</title>"))
  (goto-char (point-min))
  (while (re-search-forward "<p>{p.[\s\t\n]*" nil t)
	(replace-match "<page>")
	(re-search-forward "}</p>" nil t)
	(replace-match "</page>"))
  (goto-char (point-min))
  (while (re-search-forward "<p>{file &quot;" nil t)
	(replace-match "<file name=\"")
	(re-search-forward "&quot;}</p>" nil t)
	(replace-match "\">")
	(when (or 
		   (re-search-forward "<p>{file &quot;" nil t)
		   (re-search-forward "</div>" nil t))
	  (beginning-of-line)
	  (insert "</file>\n")))
  
  ;; STML macro replacements
  (goto-char (point-min))
  (while (re-search-forward "~hr" nil t)
	(replace-match "<hr width=\"50%\"/>"))
  (goto-char (point-min))
  (while (re-search-forward "/~" nil t)
	(replace-match "</big>"))
  (goto-char (point-min))
  (while (re-search-forward "~" nil t)
	(replace-match "<big>"))
  (goto-char (point-min))
  (while (re-search-forward "/[$]" nil t)
	(replace-match "<smallend />"))
  (goto-char (point-min))
  (while (re-search-forward "[$]" nil t)
	(replace-match "<smallstart />"))
  (goto-char (point-min))
  (while (re-search-forward "/|" nil t)
	(replace-match "</div>"))
  (goto-char (point-min))
  ;; The following is probably a bug but we've got to deal with it here
  (while (re-search-forward "<i>|</i>" nil t)
	(replace-match "<div style=\"margin-left: 32px\">"))
  (goto-char (point-min))
  (while (re-search-forward "|" nil t)
	(replace-match "<div style=\"margin-left: 32px\">"))
  (goto-char (point-min))
  (while (re-search-forward "&lt;" nil t)
	(replace-match "<span style=\"font-variant:small-caps;\">"))
  (goto-char (point-min))
  (while (re-search-forward "&gt;" nil t)
	(replace-match "</span>"))
  (goto-char (point-min))
  (while (re-search-forward "{cont}" nil t)
	(replace-match "<continuation />"))
  (goto-char (point-min))
  (while (re-search-forward "{rem[\s\t\n]*" nil t)
	(replace-match "<remark>")
	(re-search-forward "}" nil t)
	(replace-match "</remark>"))
  (goto-char (point-min))
  (while (re-search-forward "{sic[\s\t\n]*" nil t)
	(replace-match "<sic><original>")
	(re-search-forward "[\s\t\n]+" nil t)
	(replace-match "</original><replacement>")
	(re-search-forward "}" nil t)
	(replace-match "</replacement></sic>"))
  (goto-char (point-min))
  (while (re-search-forward "{prr.[\s\t\n]*" nil t)
	;; Both pr and prr are page references but pr prints "p. " before page#
	(replace-match "<pageref p=\"N\">")
	(re-search-forward "}" nil t)
	(replace-match "</pageref>"))
  (goto-char (point-min))
  (while (re-search-forward "{pr.[\s\t\n]*" nil t)
	(replace-match "<pageref p=\"Y\">")
	(re-search-forward "}" nil t)
	(replace-match "</pageref>"))
  (goto-char (point-min))
  (while (re-search-forward "{fr.[\s\t\n]*" nil t)
	(replace-match "<footnoteref>")
	(re-search-forward "}" nil t)
	(replace-match "</footnoteref>"))
  (goto-char (point-min))
  (while (re-search-forward "{fp.[\s\t\n]*" nil t)
	(replace-match "<footnotepage>")
	(re-search-forward "}" nil t)
	(replace-match "</footnotepage>"))

  ;; Do this one last as we want to elimante other STML macros before the footnoteend
  (goto-char (point-min))
  (while (re-search-forward "{fn.[\s\t\n]*" nil t)
	(replace-match "<footnotestart>")
	(re-search-forward "[.][\s\t\n]*" nil t)
	(replace-match "</footnotestart>")
	(re-search-forward "}" nil t)
	;; Needs to be a "milestone" element as footnotes can cross other elements
	(replace-match "<footnoteend />"))

  ;; Delete Table of Contents
  (goto-char (point-min))
  (while (re-search-forward "<file name=\"Table of Contents\">" nil t)
	(beginning-of-line)
	(let (start end)
	  (setq start (point))
	  (next-line)
	  (re-search-forward "<file name" nil t)
	  (beginning-of-line)
	  (setq end (point))
	  (kill-region start end)))
  
  ;; Format generated XML
  (xml-mode)
  (let (start end)
	(goto-char (point-min))
	(re-search-forward "<book>" nil t)
	(beginning-of-line)
	(setq start (point))
	(goto-char (point-max))
	(setq end (point))
	(indent-region start end))
  (save-buffer))