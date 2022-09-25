# To build, we assume that lib is mounted to /usr/local/src
FROM ubuntu:kinetic as base

# install dependencies
RUN apt-get update && apt-get install -y openjdk-8-jdk maven
RUN update-java-alternatives -s java-1.8.0-openjdk-amd64
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

FROM base as build-root
USER root

FROM base as build-user
# this docker has to write files outside the docker container with the user id and group id of the current user
ARG USER_ID
ARG GROUP_ID

# set up user/groups
RUN addgroup --gid $GROUP_ID user
RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user
RUN adduser user sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER user