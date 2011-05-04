# Makefile for the transforms directory.
#
# Build transforms that are generated
# Assumes that it will be included after the definitions in the top level Makefile
#
# Copyright 2008-2011 Efraim Feinstein
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
# $Id: Makefile 687 2011-01-23 23:36:48Z efraim.feinstein $
TRANSFORMS-DIR ?= $(CODEDIR)/transforms

TRANSFORM-OUTPUTS = $(TEXTDIR)/Tanach.html

transforms: $(TRANSFORMS-DIR)/format/xhtml/muxhtml.xsl2

$(TRANSFORMS-DIR)/format/xhtml/muxhtml.xsl2: $(TRANSFORMS-DIR)/format/xhtml/muxhtml-generator.xsl2
	$(XSLT) -it main -o $@ $(TRANSFORMS-DIR)/format/xhtml/muxhtml-generator.xsl2

.PHONY: transforms-clean
transforms-clean: 
	rm -f $(TRANSFORMS-DIR)/format/xhtml/muxhtml.xsl2

#$(TRANSFORM-OUTPUTS): $(TRANSFORMS-DIR)/transform.xsl2
#  $(XSLT) -s $(TEXTDIR)/Tanach.xml -o $(TRANSFORM-OUTPUTS) $(TRANSFORMS-DIR)/transform.xsl2
  
