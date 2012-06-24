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

.PHONY: schema-build-clean
schema-build-clean: 
	rm -fr schema/build

jlptei-schema-clean:
	rm -fr schema/build/jlptei.*

.PHONY: jlptei-schema 
jlptei-schema: schema/build/jlptei.xsl2

.PHONY: p5subset
p5subset: $(LIBDIR)/tei/P5/p5subset.xml

$(LIBDIR)/tei/P5/p5subset.xml: $(wildcard $(ODDDIR)/*.xml) $(wildcard $(ODDDIR)/*.sch) $(wildcard $(ODDDIR)/*.xsl2) $(ODDDIR)/Makefile  
	cd $(LIBDIR)/tei/P5 && make p5subset.xml 

schema/build/jlptei.doc.html: schema/build/jlptei.isosch
schema/build/jlptei.isosch: p5subset schema/jlptei.xml
	$(TEIROMA) --nodtd --noxsd --isoschematron schema/jlptei.xml schema/build
schema/build/jlptei.xsl2: schema/build/jlptei.isosch
	$(XSLT) -s $< -o $@ lib/iso-schematron/iso_svrl_for_xslt2.xsl
	
.PHONY: transliteration-schema
transliteration-schema: schema/build/transliteration.xsl2

schema/build/transliteration.xsl2: schema/transliteration.sch
	$(XSLT) -s $< -o $@ lib/iso-schematron/iso_svrl_for_xslt2.xsl

.PHONY: contributor-schema contributor-schema-clean bibliography-schema bibliography-schema-clean annotation-schema annotation-schema-clean
annotation-schema: schema/build/annotation.xsl2

contributor-schema: schema/build/contributor.rnc

bibliography-schema: schema/build/bibliography.xsl2

schema/build/contributor.rnc: p5subset schema/build schema/contributor.xml
	$(TEIROMA) --nodtd --noxsd schema/contributor.xml schema/build

schema/build/bibliography.isosch: schema/build/bibliography.rnc
schema/build/bibliography.rnc: p5subset schema/build schema/bibliography.xml
	$(TEIROMA) --nodtd --noxsd --isoschematron schema/bibliography.xml schema/build
schema/build/bibliography.xsl2: schema/build/bibliography.isosch
	$(XSLT) -s $< -o $@ lib/iso-schematron/iso_svrl_for_xslt2.xsl

schema/build/annotation.isosch: schema/build/annotation.rnc
schema/build/annotation.rnc: p5subset schema/build schema/annotation.xml
	$(TEIROMA) --nodtd --noxsd --isoschematron schema/annotation.xml schema/build
schema/build/annotation.xsl2: schema/build/annotation.isosch
	$(XSLT) -s $< -o $@ lib/iso-schematron/iso_svrl_for_xslt2.xsl

contributor-schema-clean:
	rm -fr schema/build/contributor.*

bibliography-schema-clean:
	rm -fr schema/build/bibliography.*

annotation-schema-clean:
	rm -fr schema/build/annotation.*

schema/build:
	mkdir -p schema/build
