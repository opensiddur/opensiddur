#!/usr/bin/env python
# Generate a Table of Contents (machine and human readable) for 1917 JPS project
# Copyright 2011 Marc Stober and licensed to you under the terms of the LGPL
# WORK IN PROGRESS !!!


import os.path
import sys

inp_path = sys.argv[1]
inp = open(inp_path)
outp_path = os.path.join(os.path.split(inp_path)[0], 'toc.txt')
print('Generating "%s"...' % outp_path)
outp = open(outp_path, 'w')

outp.write('# Generated from %s by %s\n' % (
        inp_path, os.path.split(sys.argv[0])))
for line in inp:
    outp.write(line)

inp.close()
outp.close()
