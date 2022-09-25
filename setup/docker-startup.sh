#!/usr/bin/env bash
export JAVA_OPTS="-Xmx3072m -Xms512m"
export CLASSPATH_PREFIX=/usr/local/opensiddur/lib/*:usr/local/opensiddur/lib/user/*
/usr/local/opensiddur/bin/startup.sh