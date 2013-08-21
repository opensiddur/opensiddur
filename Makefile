# Global Makefile
#
# Sets up rules for building, and includes Makefiles from all targets
#
# Copyright 2008-2013 Efraim Feinstein
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
# dist - make a .tar.gz for distribution
#
# db-install - install database to $(EXIST_INSTALL_DIR)
# db-uninstall - remove $(EXIST_INSTALL_DIR)
# db-sync DBAPASS=<database password> - synchronize code, data, and common from the development working copy to a running database; 
# db-syncclean - clean the __contents__.xml files left by syncing the database 
# 

# Local changes to variables should go in Makefile.local
# Any variable set in this file may be overridden by a setting in Makefile.local
-include Makefile.local

# admin password: CHANGE IT(!) in Makefile.local
ADMINPASSWORD ?= password

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
DBDIR ?= $(TOPDIR)/db
TEMPDIR ?= $(TOPDIR)/tmp

# java home... you will probably have to set this in Makefile.local
JAVA_HOME ?= /usr/lib/jvm/java-7-openjdk/

# everything that can be made depends on these files
ALL_DEPEND=Makefile $(COMMONDIR)/catalog.xml

# root directory (used only for calls to Java from cygwin)
ROOTDIR ?= 

# XSLT options: 
#	for saxon v8.9, there are none.  For version 9+, use -ext:on to allow creation of files
XSLTLOCALOPTIONS ?=
XSLTOPTIONS ?= -ext:on -x:org.apache.xml.resolver.tools.ResolvingXMLReader -y:org.apache.xml.resolver.tools.ResolvingXMLReader -r:org.apache.xml.resolver.tools.CatalogResolver $(XSLTLOCALOPTIONS) 

# Roma options: 
#	--doc makes TEI documentation, 
#	--docpdf makes PDF documentation (broken!)
#	--dochtml makes HTML documentation
ROMAOPTIONS ?= --xsl=`absolutize $(LIBDIR)/tei/Stylesheets` --doc --dochtml 

# default eXist install directory
EXIST_INSTALL_DIR ?= /usr/local/opensiddur

# paths to programs:
LOCALPATH ?= /usr/local
EXIST_INSTALL_JAR ?= $(LIBDIR)/exist/installer/eXist-db-setup-2.1-rev.jar
EXISTCLIENT ?= $(EXIST_INSTALL_DIR)/bin/client.sh
EXISTBACKUP ?= java -Dexist.home=$(EXIST_INSTALL_DIR) -jar $(EXIST_INSTALL_DIR)/start.jar org.exist.backup.Main 

RESOLVERPATH ?= $(LIBDIR)/resolver-1.2.jar
CP ?= /bin/cp
JAVAOPTIONS ?=
SAXONJAR ?= $(LIBDIR)/saxonhe-9.2.1.5.jar
# CPSEP=classpath separator - : on Unix, ; on Windows
JCLASSPATH ?= "$(RESOLVERPATH):$(SAXONJAR):$(LIBDIR)"
SAXONCLASS ?= net.sf.saxon.Transform
XSLT ?= java $(JAVAOPTIONS) -cp "$(JCLASSPATH)" -Dxml.catalog.files=$(LIBDIR)/catalog.xml -Dxml.catalog.verbosity=1 $(SAXONCLASS) $(XSLTOPTIONS) 
TEIROMA ?= $(LIBDIR)/tei/Roma/roma2.sh $(ROMAOPTIONS)

# changes for Cygwin path (experimental, not necessarily maintained!)
-include Makefile.cygwin

# directories for externals
TEIDIR = $(LIBDIR)/tei

EXISTSRCDIR = $(LIBDIR)/exist

all:  code input-conversion odddoc lib

include $(TEXTDIR)/Makefile
include $(CODEDIR)/Makefile
include $(ODDDIR)/Makefile
include $(LIBDIR)/Makefile

$(TEMPDIR):
	mkdir $(TEMPDIR)

.PHONY: schema schema-clean
schema: $(DBDIR)/schema jlptei-schema transliteration-schema contributor-schema bibliography-schema annotation-schema linkage-schema conditional-schema style-schema dictionary-schema
	cp schema/build/jlptei.rnc $(DBDIR)/schema
	cp schema/build/linkage.rnc $(DBDIR)/schema
	cp schema/build/contributor.rnc $(DBDIR)/schema
	cp schema/build/bibliography.rnc $(DBDIR)/schema
	cp schema/build/annotation.rnc $(DBDIR)/schema
	cp schema/build/conditional.rnc $(DBDIR)/schema
	cp schema/build/dictionary.rnc $(DBDIR)/schema
	cp schema/build/style.rnc $(DBDIR)/schema
	cp schema/build/*.xsl2 $(DBDIR)/schema
	cp schema/transliteration.rnc $(DBDIR)/schema
	cp schema/access.rnc $(DBDIR)/schema
	cp schema/group.rnc $(DBDIR)/schema

schema-clean: schema-build-clean
	rm -fr $(DBDIR)/schema

.PHONY: clean
clean: schema-clean code-clean input-conversion-clean db-clean db-syncclean clean-hebmorph clean-hebmorph-lucene dist-clean-exist setup-clean

$(DBDIR)/common: $(DBDIR)/code params.xsl2

RSYNC_EXCLUDE=--exclude=.svn --exclude=~*

$(DBDIR)/code: code
	#svn update $(DBDIR)
	find $(DBDIR) -name __contents__.xml | xargs rm -f
	rsync $(RSYNC_EXCLUDE) -a --delete group $(DBDIR)
	rsync $(RSYNC_EXCLUDE) -a --delete code $(DBDIR)


$(DBDIR)/schema:
	mkdir -p $(DBDIR)/schema

IZPACK:=$(shell $(LIBDIR)/absolutize $(LIBDIR)/IzPack)

# build eXist (what dependencies should this have?)
# made dependent on the Makefile because that is where the revision is set.
# It will cause too many remakes, but better than not remaking at all
$(EXIST_INSTALL_JAR): Makefile
	cd $(LIBDIR)/exist && \
		JAVA_HOME=$(JAVA_HOME) \
		./build.sh installer -Dizpack.dir=$(IZPACK) -Dinclude.module.scheduler=true -Dinclude.feature.security.oauth=true -Dinclude.feature.security.openid=true

.PHONY: build-exist clean-exist dist-clean-exist
build-exist: $(EXIST_INSTALL_JAR)

clean-exist:
	rm -f $(EXIST_INSTALL_JAR)

dist-clean-exist:
	cd $(LIBDIR)/exist && \
		JAVA_HOME=$(JAVA_HOME) \
		./build.sh clean

.PHONY: build-hebmorph build-hebmorph-lucene clean-hebmorph clean-hebmorph-lucene
build-hebmorph: $(LIBDIR)/hebmorph/java/hebmorph-core/target/hebmorph-core-1.0-SNAPSHOT.jar

$(LIBDIR)/hebmorph/java/hebmorph-core/target/hebmorph-core-1.0-SNAPSHOT.jar:
	cd $(LIBDIR)/hebmorph/java/hebmorph-core/ && \
    mvn install

clean-hebmorph:
	cd $(LIBDIR)/hebmorph/java/hebmorph-core/ && \
    mvn clean

build-hebmorph-lucene: build-hebmorph lib/hebmorph/java/hebmorph-lucene/target/hebmorph-lucene-1.0-SNAPSHOT.jar 

$(LIBDIR)/hebmorph/java/hebmorph-lucene/target/hebmorph-lucene-1.0-SNAPSHOT.jar:
	#cp $(LIBDIR)/exist/extensions/indexes/lucene/lucene*.jar $(LIBDIR)/hebmorph/java/lucene.hebrew/lib
	cd $(LIBDIR)/hebmorph/java/hebmorph-lucene && mvn install

clean-hebmorph-lucene:
	cd $(LIBDIR)/hebmorph/java/hebmorph-lucene && mvn clean

# Install a copy of the eXist database
.PHONY: db-install db-install-nonet db-install-wlc db-uninstall db-sync db-syncclean installer lucene-install copy-files copy-libs setup-password
db-install: submodules code $(EXIST_INSTALL_JAR) build-hebmorph-lucene installer lucene-install db setup-password copy-files copy-libs   

#installer that does not rely on the presence of a network. 
db-install-nonet: code $(EXIST_INSTALL_JAR) build-hebmorph-lucene installer lucene-install db-nonet setup-password copy-files copy-libs
	@echo "Done."
	touch $(EXIST_INSTALL_DIR)/EXIST.AUTOINSTALLED

# copy libraries that are stored in the filesystem
copy-libs:
	@echo "Nothing to do here."

installer: $(EXIST_INSTALL_JAR)
	expect $(SETUPDIR)/install.exp "$(EXIST_INSTALL_JAR)" "$(EXIST_INSTALL_DIR)" "$(ADMINPASSWORD)"

lucene-install: installer $(EXIST_INSTALL_DIR)/extensions/indexes/lucene/lib/hebmorph-lucene-1.0-SNAPSHOT.jar 

# KLUGE: temporarily back up commit bec2a019ddf59e69e4556b74f7d969a820b78200, the last one pre-Maven, avoids a bug.
# the source code is in the git repository.
$(EXIST_INSTALL_DIR)/extensions/indexes/lucene/lib/hebmorph-lucene-1.0-SNAPSHOT.jar:
#	cp $(LIBDIR)/hebmorph/java/hebmorph-lucene/target/hebmorph-lucene-1.0-SNAPSHOT.jar $(EXIST_INSTALL_DIR)/extensions/indexes/lucene/lib
#	cp $(LIBDIR)/hebmorph/java/hebmorph-core/target/hebmorph-core-1.0-SNAPSHOT.jar $(EXIST_INSTALL_DIR)/extensions/indexes/lucene/lib
	cp $(LIBDIR)/hebmorph.jar $(EXIST_INSTALL_DIR)/extensions/indexes/lucene/lib
	cp $(LIBDIR)/lucene.hebrew.jar $(EXIST_INSTALL_DIR)/extensions/indexes/lucene/lib

copy-files:
	$(SETUPDIR)/makedb.py -h $(EXIST_INSTALL_DIR) -p 775 -d 775 -q 755 $(DBDIR)
	@echo "Copying files to database..."
	$(EXISTBACKUP) -r `pwd`/$(DBDIR)/__contents__.xml -ouri=xmldb:exist:// -p "$(ADMINPASSWORD)"
	@echo "Running post install script..."   
	$(EXISTCLIENT) -qls -u admin -P "$(ADMINPASSWORD)" -F $(SETUPDIR)/post-install.xql

.PHONY: setup-password setup-clean
setup-password: $(SETUPDIR)/setup.xql

setup-clean: 
	rm -f $(SETUPDIR)/setup.xql

$(SETUPDIR)/setup.xql:
	@echo "Setting admin password to the value in the Makefile. You did change it Makefile.local, right?..." && \
		cat $(SETUPDIR)/setup.tmpl.xql | sed "s/ADMINPASSWORD/$(ADMINPASSWORD)/g" > $(SETUPDIR)/setup.xql && \
		echo "done."
	$(EXISTCLIENT) -qls -u admin -P "$(ADMINPASSWORD)" -F $(SETUPDIR)/setup.xql
	rm -f $(SETUPDIR)/setup.xql

#$(EXIST_INSTALL_DIR)/EXIST.AUTOINSTALLED: 
#	make db-install

# install the WLC files into $WLCDBDIR on the database and assure that they're
# ready to be used (note: may overwrite existing files, use with caution)
# reference index not being used yet, so ridx-disable/enable are disabled
db-install-wlc: tanach tanach2db 

.PHONY: tanach2db
tanach2db:
	$(SETUPDIR)/makedb.py -h $(EXIST_INSTALL_DIR) -p 774 -d 775 -c /db/data -u admin -g everyone $(TEXTDIR)/wlc
	$(EXISTBACKUP) -r `pwd`/$(WLC-OUTPUT-DIR)/__contents__.xml -u admin -p "$(ADMINPASSWORD)" -ouri=xmldb:exist://

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
db-nonet: schema transforms $(DBDIR)/code $(DBDIR)/common 
	rsync $(RSYNC_EXCLUDE) -a --delete data $(DBDIR)
	cp $(CODEDIR)/common/params.xsl2 $(DBDIR)/code/common	

db-clean:
	rm -fr $(DBDIR)/schema $(DBDIR)/code $(DBDIR)/data $(DBDIR)/common $(DBDIR)/cache

# equivalent of svn externals
.PHONY: db-externals

.PHONY: externals submodules
externals: svn-tei 

submodules:
	git submodule init
	git submodule update

.PHONY: svn-tei 
svn-tei: $(TEIDIR)
	svn update $(TEI_REVISION) $(TEIDIR)

$(TEIDIR):
	svn co $(TEIREPO) $(TEIDIR)

.PHONY: ridx-enable ridx-disable
ridx-enable:
	@echo Re-enabling the index and indexing database references. This may take a while...
	$(EXISTCLIENT) -u admin -P "$(ADMINPASSWORD)" -qls -F $(SETUPDIR)/enable-refindex.xql
	$(EXISTCLIENT) -qls -u admin -P "$(ADMINPASSWORD)" -F $(SETUPDIR)/reindex-refindex.xql

ridx-disable:
	$(EXISTCLIENT) -u admin -P "$(ADMINPASSWORD)" -qls -F $(SETUPDIR)/disable-refindex.xql

