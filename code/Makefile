# Makefile for the code directory.
#
# Sets up dependencies for the XSLT files
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
include $(CODEDIR)/grammar-parser/Makefile
include $(CODEDIR)/input-conversion/Makefile
include $(CODEDIR)/transforms/Makefile
include $(CODEDIR)/tests/Makefile

XSLTDOC_CFGFILE = XSLTDocConfig.xml
CODE_DEPEND=$(STAGE1_DEPEND) $(STAGE2_DEPEND) $(STAGE3_DEPEND)

$(DOCDIR):
	mkdir -p $(DOCDIR)

#$(CODEDOCDIR):
#	mkdir -p $(CODEDOCDIR)

.PHONY: code
code: transforms params.xsl2 
.PHONY: params.xsl2
params.xsl2: $(CODEDIR)/common/params.xsl2

.PHONY: code-depend
	
.PHONY: xsltdoc xsltdoc-clean
xsltdoc: code $(CODEDOCDIR)/index.html

$(CODEDOCDIR)/index.html: $(CODE_DEPEND) $(CODEDIR)/$(XSLTDOC_CFGFILE) $(CODEDIR)/xmlverbatim.css $(CODEDIR)/XSLTdoc.css
	mkdir -p $(CODEDOCDIR)
	$(CP) $(CODEDIR)/xmlverbatim.css $(CODEDOCDIR)
	$(CP) $(CODEDIR)/XSLTdoc.css $(CODEDOCDIR)
	$(XSLT) -s $(CODEDIR)/$(XSLTDOC_CFGFILE) $(XSLTDOC)

$(CODEDIR)/common/params.xsl2: 
	$(CP) $(CODEDIR)/common/params.tmpl.xsl2 $(CODEDIR)/common/params.xsl2

.PHONY: xsltdoc-clean
xsltdoc-clean:
	rm -fr $(DOCDIR)

.PHONY: code-clean
code-clean:  

