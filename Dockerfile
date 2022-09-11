FROM ubuntu:focal

RUN useradd -c "eXist db"  exist
# install dependencies
RUN apt-get update
RUN apt-get install -y openjdk-8-jdk

RUN mkdir -p /usr/local/opensiddur
RUN chown exist:exist /usr/local/opensiddur

USER exist:exist

# copy the build
COPY dependencies/exist-installer-*.jar /tmp/exist-installer.jar
COPY setup/docker-install-options.conf /tmp/

# run the installer
RUN java -jar /tmp/exist-installer.jar -console -options /tmp/docker-install-options.conf
COPY setup/docker-startup.sh /usr/local/opensiddur/bin/docker-startup.sh
COPY lib/icu4j-* /usr/local/opensiddur/lib/user/
COPY lib/hebmorph-exist/java/target/hebmorph-lucene.jar /usr/local/opensiddur/lib/user/
COPY lib/hebmorph-exist/hspell-data-files /usr/local/opensiddur/lib/user/

# copy autodeploy files
COPY dist/opensiddur-server.xar /usr/local/opensiddur/autodeploy

EXPOSE 8080 8443

ENTRYPOINT /usr/local/opensiddur/bin/docker-startup.sh
