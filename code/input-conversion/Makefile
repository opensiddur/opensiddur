# Makefile for the input-conversion directory.
#
# Should have 1 target for each type of input conversion.
# Assumes that it will be included after the definitions in the top level Makefile
#
# Copyright 2008-2012 Efraim Feinstein
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/
#

INPUT-CONVERSION-DIR ?= $(CODEDIR)/input-conversion
WLC-CONVERSION-DIR ?= $(CODEDIR)/input-conversion/wlc
WLC-OUTPUT-DIR ?= $(TEXTDIR)/wlc
STRONGS-CONVERSION-DIR ?= $(CODEDIR)/input-conversion/strongs
STRONGS-OUTPUT-DIR ?= $(TEXTDIR)/strongs

PATH-TO-SOURCES ?= .
TANACH-SOURCE-DIR ?= `$(LIBDIR)/absolutize $(TOPDIR)/$(PATH-TO-SOURCES)/sources/tanach/WLC/Books`
STRONGS-SOURCE ?= $(TOPDIR)/$(PATH-TO-SOURCES)/sources/StrongsDictionary/StrongHebrewG.xml

input-conversion: tanach strongs

input-conversion-clean: tanach-clean strongs-clean

# note: the output file is phony because it goes into a YYYY/MM directory
tanach: $(WLC-OUTPUT-DIR)/תנ״ך.xml

$(WLC-OUTPUT-DIR)/joined-wlc.xml: $(WLC-CONVERSION-DIR)/join-wlc.xsl2
	$(XSLT) -it main $(WLC-CONVERSION-DIR)/join-wlc.xsl2 input-directory=$(TANACH-SOURCE-DIR) output-file=$(WLC-OUTPUT-DIR)/joined-wlc.xml

$(WLC-OUTPUT-DIR)/תנ״ך.xml: $(WLC-CONVERSION-DIR)/wlc2jlptei.xsl2 $(WLC-OUTPUT-DIR)/joined-wlc.xml $(TANACH-SOURCE)
	$(XSLT) -it main $(WLC-CONVERSION-DIR)/wlc2jlptei.xsl2 input-file=`$(LIBDIR)/absolutize $(WLC-OUTPUT-DIR)/joined-wlc.xml` result-directory=`$(LIBDIR)/absolutize $(WLC-OUTPUT-DIR)`
	rm -f $(WLC-OUTPUT-DIR)/joined-wlc.xml

tanach-clean:
	rm -fr $(WLC-OUTPUT-DIR)

strongs: $(STRONGS-OUTPUT-DIR)/strongs.xml $(STRONGS-OUTPUT-DIR)/strongs-xlit.xml

$(STRONGS-OUTPUT-DIR)/strongs.xml: $(STRONGS-CONVERSION-DIR)/strongs2jlptei.xsl2 $(STRONGS-SOURCE)
	$(XSLT) -s:$(STRONGS-SOURCE) -xsl:$(STRONGS-CONVERSION-DIR)/strongs2jlptei.xsl2 -o:$(STRONGS-OUTPUT-DIR)/strongs.xml 

$(STRONGS-OUTPUT-DIR)/strongs-xlit.xml: $(STRONGS-CONVERSION-DIR)/strongs2xlittest.xsl2 $(STRONGS-SOURCE)
	$(XSLT) -s:$(STRONGS-SOURCE) -xsl:$(STRONGS-CONVERSION-DIR)/strongs2xlittest.xsl2 -o:$(STRONGS-OUTPUT-DIR)/strongs-xlit.xml 

strongs-clean:
	rm -fr $(STRONGS-OUTPUT-DIR)
