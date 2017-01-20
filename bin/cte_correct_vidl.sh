#!/bin/bash

#cte_correct.csh

# PURPOSE : To check whether all of the raw files have been converted into
#           cte files.
#
#           If they have not loop through only those files that have been
#           and correct for cte using richards software
#


  export cluster_name=${1}

  
  checkraw=`ls *_raw.fits | grep -v orig | wc -l`

  workDir=`pwd`
  
  if [ $checkraw -gt 0 ]
  then
      #Need to move any _orig_raw.fits from the dir before
      idl -e 'acs_correct_cte,DATA_DIR="'$workDir'"'
      #Clean up after ones self
      rm -fr *A.fits
      rm -fr *B.fits
      rm -fr *C.fits
      rm -fr *D.fits
  fi
  

  
