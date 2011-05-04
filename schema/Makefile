# Makefile for the schema directory.
#
# Sets up dependencies for the XSLT files
# Assumes that it will be included after the definitions in the top level Makefile
#
# Copyright 2008-2010 Efraim Feinstein
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/
#
# $Id: Makefile 452 2010-02-16 02:08:52Z efraim.feinstein $

JLPTEI_FILE=jlptei.xml

odd-depend: $(CODEDIR)/depend.xsl2 $(ALL_DEPEND) $(TEMPDIR)
		echo JLPTEIODD_DEPEND=$(ODDDIR)/$(JLPTEI_FILE) `$(XSLT)  -s $(ODDDIR)/$(JLPTEI_FILE)  $(CODEDIR)/depend.xsl2 ` >> Makefile.depend 
#		echo TRODD_DEPEND=`$(XSLT)  -s $(ODDDIR)/tr.odd  $(CODEDIR)/depend.xsl2 ` >> Makefile.depend 

.PHONY: odddoc odddoc-clean schema-clean
odddoc: jlpteidoc 
# trdoc removed

schema-clean: odddoc-clean

odddoc-clean:
	rm -fr $(TEIDOCDIR)

.PHONY: trdoc 
trdoc: $(TEIDOCDIR)/tr.doc.html

$(TEIDOCDIR)/tr.doc.html: $(TRODD_DEPEND) $(ODDDIR)/Makefile 
	$(TEIROMA) $(ODDDIR)/tr.odd $(TEIDOCDIR)

.PHONY: jlpteidoc 
jlpteidoc: $(TEIDOCDIR)/jlptei.doc.html

$(TEIDOCDIR)/jlptei.doc.html: $(JLPTEIODD_DEPEND) $(ODDDIR)/Makefile $(ODDDIR)/jlptei.xml
	$(TEIROMA) $(ODDDIR)/$(JLPTEI_FILE) $(TEIDOCDIR)
	
