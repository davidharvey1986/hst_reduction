#!/bin/bash

#cte_correct.csh

# PURPOSE : To check whether all of the raw files have been converted into
#           cte files.
#
#           If they have not loop through only those files that have been
#           and correct for cte using richards software
#


  export filename=${1}

  


  workDir=`pwd`
  

  #Need to move any _orig_raw.fits from the dir before
  idl -e 'acs_correct_cte,"'${filename}'",DATA_DIR="'$workDir'"'
  #Clean up after ones self
  rm -fr *A.fits
  rm -fr *B.fits
  rm -fr *C.fits
  rm -fr *D.fits

  

  
