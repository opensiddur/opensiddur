# Global Makefile
#
# Sets up rules for building, and includes Makefiles from all targets
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
#
# Possibilities of targets:
# all - makes code targets
# schema - schema and schema documentation for the TEI extension (places results in doc/jlp by default)
# odddoc - a synonym for schema
# xsltdoc - documentation for the XSLT code (places result in doc/code)
# dist - make a .tar.gz for distribution
#
# db-install - install database to $(EXIST_INSTALL_DIR)
# bf-install - install betterFORM extension over the database in $(EXIST_INSTALL_DIR)
# db-uninstall - remove $(EXIST_INSTALL_DIR)
# db-sync DBAPASS=<database password> - synchronize code, data, and common from the development working copy to a running database; 
# db-syncclean - clean the __contents__.xml files left by syncing the database 
# 

# Local changes to variables should go in Makefile.local
# Any variable set in this file may be overridden by a setting in Makefile.local
-include Makefile.local

# admin password: CHANGE IT(!) in Makefile.local
ADMINPASSWORD ?= password

# dependencies from make depend go in this file, which is generated by make depend
-include Makefile.depend

# assumes the directory structure of the repository
TOPDIR ?= .
CODETAG ?= .
DATATAG ?= .
TEXTTAG ?= .
ODDTAG ?= .
COMMONTAG ?= .
LIBTAG ?= .
SETUPTAG ?= .

CODEDIR ?= $(TOPDIR)/$(CODETAG)/code
DATADIR ?= $(TOPDIR)/$(DATATAG)/data
TEXTDIR ?= $(TOPDIR)/$(TEXTTAG)/text
ODDDIR ?= $(TOPDIR)/$(ODDTAG)/schema
LIBDIR ?= $(TOPDIR)/$(LIBTAG)/lib
SETUPDIR ?= $(TOPDIR)/$(SETUPTAG)/setup
COMMONDIR ?= $(TOPDIR)/$(COMMONTAG)/common
DOCDIR ?= $(TOPDIR)/doc
DBDIR ?= $(TOPDIR)/db
TEMPDIR ?= $(TOPDIR)/tmp

# java home... you will probably have to set this in Makefile.local
JAVA_HOME ?= /usr/lib/jvm/java-6-openjdk/

# everything that can be made depends on these files
ALL_DEPEND=Makefile $(COMMONDIR)/catalog.xml

# code documentation:
# when you change this directory, you also need to change the path pointed to by
# the TargetDirectory element in XSLTDocConfig.xml
CODEDOCDIR ?= $(DOCDIR)/code
# TEI extension documentation:
TEIDOCDIR ?= $(DOCDIR)/jlp

# root directory (used only for calls to Java from cygwin)
ROOTDIR ?= 

# XSLT options: 
#	for saxon v8.9, there are none.  For version 9+, use -ext:on to allow creation of files
XSLTLOCALOPTIONS ?=
XSLTOPTIONS ?= -ext:on -x:org.apache.xml.resolver.tools.ResolvingXMLReader -y:org.apache.xml.resolver.tools.ResolvingXMLReader -r:org.apache.xml.resolver.tools.CatalogResolver $(XSLTLOCALOPTIONS) 
# TeXML options: -e utf8 allows utf-8 encoded input
TEXMLOPTIONS ?= -e utf8
# Roma options: 
#	--doc makes TEI documentation, 
#	--docpdf makes PDF documentation (broken!)
#	--dochtml makes HTML documentation
ROMAOPTIONS ?= --xsl=$(LIBDIR)/tei/Stylesheets --localsource=`absolutize $(LIBDIR)/tei/P5/p5subset.xml` --doc --dochtml 

# XML validator options
RELAXNGOPTIONS ?= $(TEIDOCDIR)/jlptei.rng

# default eXist install directory
EXIST_INSTALL_DIR ?= /usr/local/opensiddur

# paths to programs:
LOCALPATH ?= /usr/local
EXIST_INSTALL_JAR ?= $(LIBDIR)/exist/installer/eXist-setup-2.0-tech-preview.jar
EXISTCLIENT ?= $(EXIST_INSTALL_DIR)/bin/client.sh
EXISTBACKUP ?= java -Dexist.home=$(EXIST_INSTALL_DIR) -jar $(EXIST_INSTALL_DIR)/start.jar org.exist.backup.Main 

RESOLVERPATH ?= $(LIBDIR)/resolver-1.2.jar
CP ?= /bin/cp
JAVAOPTIONS ?=
SAXONJAR ?= $(LIBDIR)/saxonhe-9.2.1.5.jar
# CPSEP=classpath separator - : on Unix, ; on Windows
JCLASSPATH ?= "$(RESOLVERPATH):$(SAXONJAR)"
SAXONCLASS ?= net.sf.saxon.Transform
XSLT ?= java $(JAVAOPTIONS) -cp "$(JCLASSPATH)" -Dxml.catalog.files=$(LIBDIR)/catalog.xml -Dxml.catalog.verbosity=1 $(SAXONCLASS) $(XSLTOPTIONS) 
XSLTDOC ?= $(LIBDIR)/XSLTDoc/xsl/xsltdoc.xsl
TEIROMA ?= $(LIBDIR)/tei/Roma/roma2.sh $(ROMAOPTIONS)
RELAXNG ?= $(LIBDIR)/jing $(RELAXNGOPTIONS)

# changes for Cygwin path (experimental, not necessarily maintained!)
-include Makefile.cygwin

# directories for externals
XSPECDIR = $(LIBDIR)/xspec
XSPECREPO = http://xspec.googlecode.com/svn/trunk/

XSLTFORMSDIR = $(LIBDIR)/xsltforms
XSLTFORMSREPO = https://xsltforms.svn.sourceforge.net/svnroot/xsltforms
XSLTFORMS_REVISION ?= -r 520

XSLTDOCDIR = $(LIBDIR)/XSLTDoc
XSLTDOCREPO = https://xsltdoc.svn.sourceforge.net/svnroot/xsltdoc/trunk/xsltdoc

TEIDIR = $(LIBDIR)/tei
TEIREPO = https://tei.svn.sourceforge.net/svnroot/tei/trunk

EXISTSRCDIR = $(LIBDIR)/exist
EXISTSRCREPO = https://exist.svn.sourceforge.net/svnroot/exist/stable/eXist-2.0.x
# lock eXist to a given revision
EXIST_REVISION ?= -r 16356

all:  code input-conversion xsltdoc odddoc lib

include $(TEXTDIR)/Makefile
include $(CODEDIR)/Makefile
include $(ODDDIR)/Makefile
include $(LIBDIR)/Makefile
include tests/Makefile

XSLTDOC_CFGFILE ?= XSLTDocConfig.xml

$(TEMPDIR):
	mkdir $(TEMPDIR)

.PHONY: depend depend-clean
depend: depend-clean $(CODEDIR)/depend.xsl2 $(ALL_DEPEND) code-depend text-depend odd-depend

depend-clean: 
	rm -f Makefile.depend $(TEMPDIR)/dump.depend

schema: odddoc

.PHONY: clean
clean: xsltdoc-clean dist-clean depend-clean odddoc-clean code-clean input-conversion-clean db-clean db-syncclean clean-hebmorph clean-hebmorph-lucene dist-clean-exist

dist:
	svnversion -n $(TOPDIR) | sed -e "s/:/-/g" > opensiddur-version
	svn export $(TOPDIR) opensiddur-package
	tar zcvf opensiddur-package-r`cat opensiddur-version`.tar.gz opensiddur-package
	rm -fr opensiddur-package opensiddur-version

dist-clean:

$(DBDIR)/common: $(DBDIR)/code

RSYNC_EXCLUDE=--exclude=.svn --exclude=~*

$(DBDIR)/code: code
	#svn update $(DBDIR)
	find $(DBDIR) -name __contents__.xml | xargs rm -f
	rsync $(RSYNC_EXCLUDE) -a --delete group $(DBDIR)
	rsync $(RSYNC_EXCLUDE) -a --delete code $(DBDIR)


$(DBDIR)/schema:
	mkdir -p $(DBDIR)/schema
	cp -R $(TEIDOCDIR)/* $(DBDIR)/schema
	cp schema/transliteration.* $(DBDIR)/schema
	cp -R schema/iso-schematron $(DBDIR)/schema
	make $(DBDIR)/schema/transliteration.xsl2

$(DBDIR)/schema/transliteration.xsl2: schema/transliteration.sch
	$(XSLT) -s $< -o $@ lib/iso-schematron/iso_svrl_for_xslt2.xsl


IZPACK:=$(shell $(LIBDIR)/absolutize $(LIBDIR)/IzPack)

# build eXist (what dependencies should this have?)
$(EXIST_INSTALL_JAR):
	cp setup/exist-extensions-local.build.properties $(LIBDIR)/exist/extensions/local.build.properties
	rm -f $(LIBDIR)/exist/extensions/indexes/lucene/lib/*2.9.2.jar
	cp $(LIBDIR)/hebmorph/java/lucene.hebrew/lib/lucene*2.9.3.jar $(LIBDIR)/exist/extensions/indexes/lucene/lib
	cd $(LIBDIR)/exist && \
		JAVA_HOME=$(JAVA_HOME) \
		./build.sh svn-download
	cd $(LIBDIR)/exist && \
		JAVA_HOME=$(JAVA_HOME) \
		./build.sh installer -Dizpack.dir=$(IZPACK) -Dinclude.module.scheduler=true

.PHONY: build-exist clean-exist dist-clean-exist
build-exist: $(EXIST_INSTALL_JAR)

clean-exist:
	rm -f $(EXIST_INSTALL_JAR)

dist-clean-exist:
	cd $(LIBDIR)/exist && \
		JAVA_HOME=$(JAVA_HOME) \
		./build.sh clean

.PHONY: build-hebmorph build-hebmorph-lucene clean-hebmorph clean-hebmorph-lucene
build-hebmorph: $(LIBDIR)/hebmorph/java/hebmorph/build/distribution/hebmorph.jar

$(LIBDIR)/hebmorph/java/hebmorph/build/distribution/hebmorph.jar:
	cd $(LIBDIR)/hebmorph/java/hebmorph/ && \
    ant jar

clean-hebmorph:
	cd $(LIBDIR)/hebmorph/java/hebmorph/ && \
    ant clean

build-hebmorph-lucene: build-hebmorph $(LIBDIR)/hebmorph/java/lucene.hebrew/build/distribution/lucene.hebrew.jar 

$(LIBDIR)/hebmorph/java/lucene.hebrew/build/distribution/lucene.hebrew.jar:
	cd $(LIBDIR)/hebmorph/java/lucene.hebrew/ && ant jar

clean-hebmorph-lucene:
	cd $(LIBDIR)/hebmorph/java/lucene.hebrew/ && ant clean

# Install a copy of the eXist database
.PHONY: db-install db-install-nonet db-install-wlc bf-install db-uninstall db-sync db-syncclean installer patches lucene-install copy-files copy-libs setup-password
db-install: submodules svn-exist code $(EXIST_INSTALL_JAR) build-hebmorph-lucene installer patches lucene-install db setup-password copy-files copy-libs   

#installer that does not rely on the presence of a network. 
db-install-nonet: code $(EXIST_INSTALL_JAR) build-hebmorph-lucene installer patches lucene-install db-nonet setup-password copy-files copy-libs
	@echo "Done."
	touch $(EXIST_INSTALL_DIR)/EXIST.AUTOINSTALLED

# copy libraries that are stored in the filesystem
copy-libs:
	mkdir -p $(EXIST_INSTALL_DIR)/webapp/aloha
	cp -r $(LIBDIR)/aloha/src/* $(EXIST_INSTALL_DIR)/webapp/aloha

installer: $(EXIST_INSTALL_JAR)
	java -jar $(EXIST_INSTALL_JAR) -p $(EXIST_INSTALL_DIR)

patches:
	$(XSLT) -s $(EXIST_INSTALL_DIR)/conf.xml -o $(EXIST_INSTALL_DIR)/conf.xml $(SETUPDIR)/setup-conf-xml.xsl2
	-patch -Nd $(EXIST_INSTALL_DIR) < $(SETUPDIR)/mime-types.xml.patch
	-patch -Nd $(EXIST_INSTALL_DIR)/webapp/WEB-INF < $(SETUPDIR)/controller-config.xml.patch
	-patch -Nd $(EXIST_INSTALL_DIR)/tools/jetty/etc < $(SETUPDIR)/jetty.xml.patch

lucene-install: installer $(EXIST_INSTALL_DIR)/extensions/indexes/lucene/lib/lucene.hebrew.jar 

$(EXIST_INSTALL_DIR)/extensions/indexes/lucene/lib/lucene.hebrew.jar:
	cp $(LIBDIR)/hebmorph/java/lucene.hebrew/build/distribution/lucene.hebrew.jar $(EXIST_INSTALL_DIR)/extensions/indexes/lucene/lib

copy-files:
	$(SETUPDIR)/makedb.py -h $(EXIST_INSTALL_DIR) -p 775 $(DBDIR)
	@echo "Copying files to database..."
	@#copy the transliteration DTD first so eXist will know where they are during restore 
	cp $(SETUPDIR)/opensiddur-catalog.xml $(EXIST_INSTALL_DIR)/webapp/WEB-INF
	cp $(SETUPDIR)/hebrew.dtd $(EXIST_INSTALL_DIR)/webapp/WEB-INF/entities
	@#then copy the code so eXist will know where the triggers and support modules are during restore, then copy everything else with system *last* so the triggers will not engage
	@#finally, copy the transforms directory again so the tests that require the document URI trigger will run
	for d in cache code data group schema xforms system code/transforms; do \
	$(EXISTBACKUP) -r `pwd`/$(DBDIR)/$$d/__contents__.xml -ouri=xmldb:exist:// -p "$(ADMINPASSWORD)"; \
	done 

.PHONY: setup-password
setup-password: $(SETUPDIR)/setup.xql

$(SETUPDIR)/setup.xql:
	@echo "Setting admin password to the value in the Makefile. You did change it Makefile.local, right?..." && \
		cat $(SETUPDIR)/setup.tmpl.xql | sed "s/ADMINPASSWORD/$(ADMINPASSWORD)/g" > $(SETUPDIR)/setup.xql && \
		echo "done."
	$(EXISTCLIENT) -qls -u admin -F $(SETUPDIR)/setup.xql
	rm -f $(SETUPDIR)/setup.xql

#$(EXIST_INSTALL_DIR)/EXIST.AUTOINSTALLED: 
#	make db-install

# install the WLC files into $WLCDBDIR on the database and assure that they're
# ready to be used (note: may overwrite existing files, use with caution)
db-install-wlc: ridx-disable tanach tanach2db ridx-enable

.PHONY: tanach2db
tanach2db:
	$(SETUPDIR)/makedb.py -h $(EXIST_INSTALL_DIR) -p 774 -c /db/group/everyone -u admin -g everyone $(TEXTDIR)/wlc
	$(EXISTBACKUP) -r `pwd`/$(WLC-OUTPUT-DIR)/__contents__.xml -u admin -p "$(ADMINPASSWORD)" -ouri=xmldb:exist://

# Install a new copy of the database with betterFORM trunk
bf-install: db-install
  echo "WARNING: BETTERFORM EXTENSION IS BROKEN NOW!"
	mkdir -p $(EXIST_INSTALL_DIR)/extensions/betterform
	cp lib/betterform.zip $(EXIST_INSTALL_DIR)/extensions/betterform
	cd $(EXIST_INSTALL_DIR)/extensions/betterform && unzip betterform.zip && ant install
	cp $(SETUPDIR)/controller-config.xml.bf $(EXIST_INSTALL_DIR)/webapp/WEB-INF/controller-config.xml
	touch $(EXIST_INSTALL_DIR)/BF.AUTOINSTALLED

db-syncclean:
	for f in `find . -name __contents__.xml`; do rm "$$f"; done

db-uninstall:
	@echo "WARNING: This will remove the copy of eXist in $(EXIST_INSTALL_DIR) within 10s. If you do not want to do that, cancel now with ctrl-c!!!!" && \
	sleep 10 && \
	echo "too late." && \
	rm -fr $(EXIST_INSTALL_DIR)

# synchronize the contents of the development directories to a running db
# (a bit of a misnomer, since it will not delete files from the db!)
db-sync:
	$(SETUPDIR)/makedb.py -h $(EXIST_INSTALL_DIR) -p 755 -c /db/code $(CODEDIR) 
	$(SETUPDIR)/makedb.py -h $(EXIST_INSTALL_DIR) -p 775 -g everyone -c /db/data $(DATADIR) 
	$(SETUPDIR)/makedb.py -h $(EXIST_INSTALL_DIR) -p 755 -c /db/common $(COMMONDIR) 
	$(EXISTBACKUP) -u admin -p $(DBAPASS) -r `pwd`/$(CODEDIR)/__contents__.xml -ouri=xmldb:exist://localhost:8080/xmlrpc
	$(EXISTBACKUP) -u admin -p $(DBAPASS) -r `pwd`/$(DATADIR)/__contents__.xml -ouri=xmldb:exist://localhost:8080/xmlrpc
	$(EXISTBACKUP) -u admin -p $(DBAPASS) -r `pwd`/$(COMMONDIR)/__contents__.xml -ouri=xmldb:exist://localhost:8080/xmlrpc

.PHONY: db db-nonet
db: externals db-nonet

# patch error status ignored because it returns 1 if patches are already applied
db-nonet: schema transforms $(DBDIR)/code $(DBDIR)/common $(DBDIR)/schema db-tests
	mkdir -p $(DBDIR)/xforms
	rsync $(RSYNC_EXCLUDE) -a --delete $(LIBDIR)/xsltforms/trunk/build/ $(DBDIR)/xforms/xsltforms
	rsync $(RSYNC_EXCLUDE) -a --delete $(LIBDIR)/xspec $(DBDIR)/code/modules/resources
	rsync $(RSYNC_EXCLUDE) -a --delete data $(DBDIR)
	cp $(CODEDIR)/common/params.xsl2 $(DBDIR)/code/common	
	-patch -p1 -Nr - < $(SETUPDIR)/generate-common-tests.xsl.patch
	-patch -p1 -Nr - < $(SETUPDIR)/generate-tests-utils.xsl.patch
	-patch -p1 -Nr - < $(SETUPDIR)/generate-xspec-tests.xsl.patch

db-clean:
	rm -fr $(DBDIR)/schema $(DBDIR)/code $(DBDIR)/data $(DBDIR)/common $(DBDIR)/cache

# equivalent of svn externals
.PHONY: db-externals

.PHONY: externals submodules
externals: svn-xspec svn-xsltforms svn-xsltdoc svn-tei svn-exist

submodules:
	git submodule init
	git submodule update

.PHONY: svn-xspec svn-xsltforms svn-xsltdoc svn-tei svn-exist
svn-xspec: $(XSPECDIR)
	svn update $(XSPECDIR)

$(XSPECDIR):
	svn co $(XSPECREPO) $(XSPECDIR)

svn-xsltforms: $(XSLTFORMSDIR)
	svn update $(XSLTFORMS_REVISION) $(XSLTFORMSDIR)

$(XSLTFORMSDIR):
	svn co $(XSLTFORMS_REVISION) $(XSLTFORMSREPO) $(XSLTFORMSDIR)

svn-xsltdoc: $(XSLTDOCDIR)
	svn update $(XSLTDOCDIR)

$(XSLTDOCDIR):
	svn co $(XSLTDOCREPO) $(XSLTDOCDIR)

svn-tei: $(TEIDIR)
	svn update $(TEIDIR)

$(TEIDIR):
	svn co $(TEIREPO) $(TEIDIR)

svn-exist: $(EXISTSRCDIR)
	svn update $(EXIST_REVISION) $(EXISTSRCDIR)

$(EXISTSRCDIR):
	svn co $(EXIST_REVISION) $(EXISTSRCREPO) $(EXISTSRCDIR)

.PHONY: ridx-enable ridx-disable
ridx-enable:
	@echo Re-enabling the index and indexing database references. This may take a while...
	$(EXISTCLIENT) -u admin -P "$(ADMINPASSWORD)" -qls -F $(SETUPDIR)/enable-refindex.xql
	$(EXISTCLIENT) -qls -u admin -P "$(ADMINPASSWORD)" -F $(SETUPDIR)/reindex-refindex.xql

ridx-disable:
	$(EXISTCLIENT) -u admin -P "$(ADMINPASSWORD)" -qls -F $(SETUPDIR)/disable-refindex.xql

