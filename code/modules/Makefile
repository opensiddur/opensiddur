# Makefile for the queries directory.
#
# Make admin.xql
#
# Copyright 2010 Efraim Feinstein
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
# $Id: Makefile 687 2011-01-23 23:36:48Z efraim.feinstein $\

QUERYDIR = modules

.PHONY: queries queries-clean
queries: $(CODEDIR)/$(QUERYDIR)/admin.xqm
queries-clean: 
	rm -f $(CODEDIR)/$(QUERYDIR)/admin.xqm

$(CODEDIR)/$(QUERYDIR)/admin.xqm: $(CODEDIR)/$(QUERYDIR)/admin.tmpl.xqm
	@read -p "Password for userman database user (enter for none): " APASS && \
		echo "Setting userman password..." && \
		cat $(CODEDIR)/$(QUERYDIR)/admin.tmpl.xqm | sed "s/\*PASSWORD\*/$$APASS/g" > $(CODEDIR)/$(QUERYDIR)/admin.xqm && \
		echo "done."
