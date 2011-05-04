# Makefile for the text directory.
#
# Sets up dependencies for the XSLT files
# Assumes that it will be included after the definitions in the top level Makefile
#
# Copyright 2008-2009 Efraim Feinstein
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
# $Id: Makefile 298 2009-11-12 00:13:04Z efraim.feinstein $


# this is the file we want to start from building:
#MAINFILE = haggadah.tei
MAINFILE = haggadat-mah-zot.tei

# NO NEED TO EDIT BEYOND THIS POINT

REVISIONXML = $(TEXTDIR)/revision.xml

# these are the files that should be validated as TEI
TEIFILES = $(TEXTDIR)/haggadah.tei \
	$(TEXTDIR)/haggadah-en.tei \
	$(TEXTDIR)/haggadah-notes.tei \
	$(TEXTDIR)/haggadat-mah-zot.tei \
	$(TEXTDIR)/haggadah-instruct.tei

# these are files that shouldn't be validated directly as TEI
# but should be valid when transcluded into certain parts of TEI files
HELPERTEXTFILES = $(TEXTDIR)/gpl-3.0.jtei \
	$(TEXTDIR)/settings.xml 

TRANSLITERATION_TABLES = $(COMMONDIR)/*.tr.xml

TEXT_DEPEND=$(MAINFILE_DEPEND) $(TEXTDIR)/Makefile $(TRANSLITERATION_TABLES)

text-depend: $(ALL_DEPEND) $(TEMPDIR) $(CODEDIR)/depend.xsl2
	echo MAINFILE_DEPEND=`$(XSLT)  -s $(TEXTDIR)/$(MAINFILE)  $(CODEDIR)/depend.xsl2` >> Makefile.depend 2> $(TEMPDIR)/dump.depend
	echo TANACH_DEPEND = `$(XSLT)  -s $(TEXTDIR)/Tanach.tei  $(CODEDIR)/depend.xsl2` >> Makefile.depend 2> $(TEMPDIR)/dump.depend

.INTERMEDIATE: bandits-siddur.xml1
bandits-siddur.xml1: $(REVISIONXML) $(TEXT_DEPEND) $(STAGE1_DEPEND) $(TEMPDIR)
	$(XSLT) -o $@ -s $(TEXTDIR)/bandits-siddur.tei $(CODEDIR)/stage1.xsl2 2> $(TEMPDIR)/dump.1


.INTERMEDIATE: haggadah.xml1
haggadah.xml1: $(REVISIONXML) $(TEXT_DEPEND) $(STAGE1_DEPEND) $(TEMPDIR)
	$(XSLT) -o $@ -s $(TEXTDIR)/$(MAINFILE) $(CODEDIR)/stage1.xsl2 2> $(TEMPDIR)/dump.1

.INTERMEDIATE: Tanach.xml1
Tanach.xml1: $(TEXTDIR)/Tanach.tei  $(TANACH_DEPEND) $(STAGE1_DEPEND) $(TEMPDIR)
	$(XSLT) -o $@ -s $(TEXTDIR)/Tanach.tei $(CODEDIR)/stage1.xsl2 2> $(TEMPDIR)/dump.1

# revision.xml can't depend on itself, so use subst to make sure it's not in $TEXT_DEPEND
$(REVISIONXML): TEXT_DEPEND_NOREVISION = $(subst $(REVISIONXML), ,$(TEXT_DEPEND))
$(REVISIONXML): $(CODEDIR)/revision.xml.sh $(CODE_DEPEND) $(TEXT_DEPEND_NOREVISION) $(ODD_DEPEND)
	$(CODEDIR)/revision.xml.sh $(REVISIONXML) $(TOPDIR)

tanach-text: tanach $(TEXTDIR)/Tanach.html

validate: $(TEIFILES) $(HELPERTEXTFILES) odddoc validate-clean
	for t in $(TEIFILES); do $(RELAXNG) "$${t}" >> $(TEMPDIR)/dump.validate 2>> $(TEMPDIR)/dump.validate.err; done

validate-clean:
	rm -f $(TEMPDIR)/dump.validate $(TEMPDIR)/dump.validate.err

haggadah-postcompile:
	rm -f $(REVISIONXML)

haggadah-clean: validate-clean
	rm -f $(TEMPDIR)/dump*
	rm -f *.xml1 *.xml2 *.texml *.tex
	rm -f *.bib *.bbl *.blg *.aux *.log *.out *.pdf
	rm -f $(REVISIONXML)

#tanach-clean:
#	rm -f Tanach.pdf Tanach.aux Tanach.out Tanach.xml? Tanach.texml Tanach.tex
