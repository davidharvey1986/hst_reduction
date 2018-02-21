'''
This code is a wrapper for the cte correction code of Richards
At the moment it just uses the IDL version

I need to update this to the C version, but I am having
problems install that.

'''

import os as os
import glob as glob
import get_acs_reffiles as gar
import multi_to_single_fits as mts
import run_arctic as rc
def cte_correct( files='j*q_raw.fits', idl=True ):
    '''
    This code will loop through each file and correct the cte
    for each image

    OPTIONAL INPUTS : files : a string of the files to cte_correct

    KEYWORDS :
           idl : use the idl version of the cte correction,
                 note, that the diretory 'bin' here needs to be in the idl path
    DEPENDENCIES : ACS-CTE Correction Binary in the PATH
    '''
    code_dir = '/'.join(os.path.abspath(__file__).split('/')[:-1])
    
    if idl:
        idl_command = code_dir+"/bin/cte_correct_vidl.sh"
        
        for iRaw_File in glob.glob(files):
           
            cte_file = iRaw_File[:-9]+"_cte.fits"
            out_file = iRaw_File[:-9]+"_cte_raw.fits"
            if not os.path.isfile( out_file ):
                gar.get_acs_reffiles( iRaw_File, ext='bia', add_jref=False)
                #The bias files cant be in the jref directory for the idl
                if os.environ['jref'] != './':
                    os.system('cp '+os.environ['jref']+'/*bia* .')
                os.system( idl_command+' '+iRaw_File[:-9] )
                os.system( "mv "+cte_file+" "+out_file)
    else:
        command = "arctic.sh"
        print files
        for iRaw_File in glob.glob(files):
            print files
            gar.get_acs_reffiles( iRaw_File, ext='bia' )
            out_file = iRaw_File[:-9]+"_cte_raw.fits"
            if not os.path.isfile( out_file ):
                #Arctic cannot run multi-extension fits yet
                rc.run_arctic( iRaw_File, out_file)
                
            else:
                print("%s already corrected for CTE " %
                    iRaw_File )

  

    
            
        
