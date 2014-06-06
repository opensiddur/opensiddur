#!/usr/bin/env python
# Simple include script.
# For the 1917 JPS PDF extraction project for the Open Siddur Project.
# Copyright 2011-13 Marc Stober and licensed under the terms of the LGPL.

import os.path
import sys

def get_lines(path):
	my_file = open(path)
	lines = my_file.readlines()
	my_file.close()
	return lines

template = get_lines(sys.argv[2])

for line in template:
	print line.strip()
	if 'INSERT HERE' in line:
		content = get_lines(sys.argv[1])
		for line in content:
			print line.strip()

