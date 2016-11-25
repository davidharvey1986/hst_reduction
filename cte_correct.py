'''
This code is a wrapper for the cte correction code of Richards
At the moment it just uses the IDL version

I need to update this to the C version, but I am having
problems install that.

'''

import os as os
import glob as glob
import get_acs_reffiles as gar

def cte_correct( files='j*q_raw.fits' ):
    '''
    This code will loop through each file and correct the cte
    for each image

    OPTIONAL INPUTS : files : a string of the files to cte_correct
    
    DEPENDENCIES : ACS-CTE Correction Binary in the PATH
    '''
    
    idl_command = "acs-cte"
    
    for iRaw_File in glob.glob(files):
        gar.get_acs_reffiles( iRaw_File, ext='bia' )
        cte_file = iRaw_File[:-9]+"_cte.fits"
        out_file = iRaw_File[:-9]+"_cte_raw.fits"
        if not os.path.isfile( out_file ):
            os.system( idl_command+" _raw "+iRaw_File)
            os.system( "mv "+cte_file+" "+out_file)
            os.system( "rm -fr *A.fits")
            os.system( "rm -fr *B.fits")
            os.system( "rm -fr *C.fits")
            os.system( "rm -fr *D.fits")
        else:
            print("%s already corrected for CTE " %
                  iRaw_File )

   
    
            
        
