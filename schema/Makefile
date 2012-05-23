# Makefile for the schema directory.
#
# Sets up dependencies for the XSLT files
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
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/
#

# the TEI dependencies include everything 
TEI_DEPENDENCIES:=$(wildcard $(LIBDIR)/tei/P5/Source/Specs/*.xml)
TEI_ALL_ODD = $(LIBDIR)/tei/P5/Exemplars/tei_all.odd

JLPTEI_FILE=jlptei.xml

.PHONY: odddoc odddoc-clean schema-clean
odddoc: jlpteidoc 
# trdoc removed

schema-clean: odddoc-clean transliteration-schema-clean

odddoc-clean:
	rm -fr $(TEIDOCDIR)

.PHONY: jlpteidoc 
jlpteidoc: $(TEIDOCDIR)/jlptei.doc.html

.PHONY: p5subset
p5subset: $(LIBDIR)/tei/P5/p5subset.xml

$(LIBDIR)/tei/P5/p5subset.xml:
	cd $(LIBDIR)/tei/P5 && make p5subset.xml 

$(TEIDOCDIR)/jlptei.doc.html: p5subset $(wildcard $(ODDDIR)/*.xml) $(wildcard $(ODDDIR)/*.sch) $(wildcard $(ODDDIR)/*.xsl2) $(ODDDIR)/Makefile 
	$(TEIROMA) $(ODDDIR)/$(JLPTEI_FILE) $(TEIDOCDIR)
	
.PHONY: transliteration-schema
transliteration-schema: $(DBDIR)/schema $(DBDIR)/schema/transliteration.xsl2
	cp schema/transliteration.* $(DBDIR)/schema

$(DBDIR)/schema/transliteration.xsl2: schema/transliteration.sch
	$(XSLT) -s $< -o $@ lib/iso-schematron/iso_svrl_for_xslt2.xsl

.PHONY: contributor-schema contributor-schema-clean
contributor-schema: schema/build/contributor.rnc

schema/build/contributor.rnc: schema/build schema/contributor.xml
	$(TEIROMA) --nodtd --noxsd schema/contributor.xml schema/build

contributor-schema-clean:
	rm -fr schema/build

schema/build:
	mkdir -p schema/build
