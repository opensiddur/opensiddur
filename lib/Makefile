# Makefile for lib directory
#
# Included from main makefile
#
# Copyright 2009 Efraim Feinstein
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
#

TTF2EOTDIR = $(LIBDIR)/ttf2eot-0.0.2-2
TTF2EOT = $(TTF2EOTDIR)/ttf2eot

EZRADIR = $(LIBDIR)/EzraSIL2.51

EZRATTFS = $(EZRADIR)/SILEOTSR.ttf $(EZRADIR)/SILEOT.ttf
EZRAOETS = $(EZRADIR)/BHebrewSR.oet $(EZRADIR)/BHebrew.ttf

$(TTF2EOT): $(TTF2EOTDIR)/OpenTypeUtilities.cpp $(TTF2EOTDIR)/OpenTypeUtilities.h $(TTF2EOTDIR)/ttf2eot.cpp
	cd $(TTF2EOTDIR) && make

%.eot: %.ttf $(TTF2EOT)
	$(TTF2EOT) $< $@

$(EZRAOETS): $(EZRATTFS)

.PHONY: lib
lib: $(EZRAOETS)
