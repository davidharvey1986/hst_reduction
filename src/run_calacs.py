'''
This is a script wrapper for the calacs.e
progrma that flat fields the hst files

Calacs.e requires 2 things:
A input 'raw' file so need to convert the _cte.fits' to raw
A preceeding jref on all the reference files, so this function checks to see if they exist and then adds jref then calls calacs on the input file. Then removes them so the user never knows

Author : David Harvey

Date : 13/112012

read in all the cte files created the file below and loop through each one
and calibrate

When i start this code I am in reffiles

Before I get going, clean up all previous attempts at
calacing

'''
import os as os
from acstools import calacs
import glob as glob
import get_acs_reffiles as gar

def run_calacs( FitsFiles='j*q_cte_raw.fits' ):
    '''
    PURPOSE : This script will take in a bunch of CTE files
              and loop through each one, finding the required
              reference files, download any missing ones and
              flat field the FitsFiles.

    OPTIONAL INPUT : fitsfile : a string of the fitsfile including the path to calacs

    OUTPUT : N images with the extension FLT which will be the flat fielded
             images of FitsFiles, where N is the number of input images

             A file called 'calacs.lis' which is a list of the files
             which were run through calacs    
    '''
    calacs_list = open('calacs.lis','wb')
    #First make sure i have all the files i need to
    #calac

    for iCTE_file in glob.glob(FitsFiles):
        #Get any missing reference files
        gar.get_acs_reffiles( iCTE_file, ext='all' )
        calacs_list.write( iCTE_file+'\n' )
        print("Running CALACS on %s" %
              iCTE_file )
        flt_file = iCTE_file[:-9]+'_flt.fits'
        if not os.path.isfile( flt_file ):
            calacs.calacs(iCTE_file)
        else:
            print('Already ran CALACS on %s' % iCTE_file)
            
    calacs_list.close()
