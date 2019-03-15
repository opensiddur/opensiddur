FROM ubuntu:cosmic

RUN useradd -c "eXist db"  exist
# install dependencies
RUN apt-get update
RUN apt-get install -y openjdk-8-jdk

RUN mkdir -p /usr/local/opensiddur
RUN chown exist:exist /usr/local/opensiddur

USER exist:exist

# copy the build
COPY lib/exist/installer/eXist-db-setup-*-opensiddur.jar /tmp/
COPY setup/docker-install-options.conf /tmp/

# run the installer
RUN java -jar /tmp/eXist-db-setup-4.6.1-opensiddur.jar -console -options /tmp/docker-install-options.conf
COPY lib/icu4j-* /usr/local/opensiddur/lib/user/
COPY lib/hebmorph-exist/java/target/hebmorph-lucene.jar /usr/local/opensiddur/lib/extensions/indexes/lucene/lib/
COPY lib/hebmorph-exist/hspell-data-files /usr/local/opensiddur/extensions/indexes/lucene/lib/
RUN ln -s /usr/local/opensiddur/extensions/indexes/lucene/lib/hspell-data-files /usr/local/opensiddur/tools/yajsw/target/classes/hspell-data-files

# copy autodeploy files
COPY dist/opensiddur-server.xar /usr/local/opensiddur/autodeploy
COPY dist/opensiddur-tests.xar /usr/local/opensiddur/autodeploy

EXPOSE 8080 8443

ENTRYPOINT /usr/local/opensiddur/bin/startup.sh
