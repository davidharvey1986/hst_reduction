#!/bin/sh
export infile=${1}
arctic_acs.py -m ACS ${infile} $*
