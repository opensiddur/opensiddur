# Makefile for the tests directory.
#
# Allows make tests to run all the available automated tests, independent of where they are located
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
# $Id: Makefile 775 2011-05-01 06:46:55Z efraim.feinstein $

XSPEC=$(LIBDIR)/xspec.sh

# add to the Python path to allow tests
NEWPYTHONPATH := $(CODEDIR)/tests
ifneq ($(PYTHONPATH),)
PYTHONPATH := $(PYTHONPATH):$(NEWPYTHONPATH)
else
PYTHONPATH := $(NEWPYTHONPATH)
endif
export PYTHONPATH := $(PYTHONPATH)

.PHONY: prepare-tests
prepare-tests: test-db-running
	curl -u testuser:testuser http://localhost:8080/code/tests/setup-test-cache.xql

.PHONY: test-triggers
test-triggers: test-db-running
	python $(CODEDIR)/triggers/tests/test_document_uri_trigger.py -v

.PHONY: test-special-uri
test-special-uri: test-db-running
	python $(CODEDIR)/tests/test_special_uri.py -v

.PHONY: test-concurrent
test-concurrent:
	$(XSPEC) $(CODEDIR)/transforms/concurrent/tests/concurrent.xspec

.PHONY: test-follow-uri
test-follow-uri:
	$(XSPEC) $(CODEDIR)/transforms/tests/follow-uri.xspec

.PHONY: test-xslt
test-xslt: test-concurrent test-follow-uri

.PHONY: test-modules
test-modules: test-db-running
	python $(CODEDIR)/tests/test_app_module.py -v

.PHONY: tests
tests: test-triggers test-special-uri test-xslt test-modules

.PHONY: test-concurrent-clean
test-concurrent-clean:
	rm -fr $(CODEDIR)/transforms/concurrent/tests/xspec

.PHONY: test-db-running
test-db-running:
	python $(CODEDIR)/tests/is-db-running.py

.PHONY: tests-clean
tests-clean: test-concurrent-clean
