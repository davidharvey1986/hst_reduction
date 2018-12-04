'''
This is the main file that will reduce all
the hubble data given to him

This script is designed to run all the other sub scripts
to fully reduce the hubble data downloaded from MAST such
that it is ready to input into lensfit
These include
1. acs_correct_cte (RJ MASSEY)
2. calacs.sh (HARVEY)
3. drizzle.sh (HARVEY)
4. sextract the image
5. Create the psf files from stack_psf.py

In order for this to work it needs
A. Fully downloaded reference files in a folder called clustername/CTE/reffiles
B. Fully downloaded _raw.fits files in clustername/CTE
C. Environment setting of the jref --> reffiles [done within]
D. The cluster name from the command line [done within]
E. _bia.fits files in the main directory /CTE/ [done within]

The pipeline goes
1. Run Richards CTE on the raw data _raw.fits --> _cte.fits
2. Run calacs.sh which calibrates the files _cte.fits --> _flt.fits
3. Run astrodrizzle using the drizzle.py in the python path _flt.fits --> _drz.fits
   This will then also take the _drz_sci.fits imcopy --> cluster_name.fits
4. Sextract the sources for the image
5. Stac the psfs into one file so it can be used in lenfit

Has been updated for the new computer
Need to be in the correct directory for this to work

'''
import cte_correct as cte
import run_calacs as run_calacs
import get_hst_band as ghb
import drizzle as drizzle
import numpy as np
import glob as glob
import os as os
import sys
import argparse as ap
import pyfits as fits
import CheckTargName as CheckTargets
import CheckExposureTime as CheckExposureTime

def main( cluster, single=False, drizzle_kernel='square', idl=True,
          pixel_scale=0.03, wht_file='ERR', jref_path='./',\
              search_rad=1., thresh=1.):
    '''
    The main function to do what is explained in docs/README

    INPUT : CLUSTER : A STRING OF THE NAME OF THE CLUSTER THAT WILL BE PUT OUT
                      AT THE END
    KEYWORDS:
        SINGLE : If True, a drizzled image of each exposure is produced.
             These are used for PSF estimation.
             WARNING: If you are drizzling together a lot of images
             this will produce a lot of data (Each drz image is ~300mb)
        Following are drizzle options, see drizzle.py for more:

        DRIZZLE_KERNEL : The kernel used in the final drizzlign stage
        PIXEL_SCALE : the final pixel scale of the drizzled image
        WHT_FILE : the type of weight file wanted to output. 
        IDL : If true use the idl version of the CTI corretion
        SEARCH_RAD: the search radius for when aligning images, can be either a float of an array. If array must be the same length as the number of filters
        THRESH: S/N thresh for sources to be used to align imagescan be either afloat of an array. If array must be the same length as the number of filters

    '''
    os.environ['jref'] = jref_path

    sys.stdout = Logger("hst_reduction.log")

    #Test for the environment variable

    if 'HST_REDUCTION' not in os.environ.keys():
        raise ValueError("HST_REDUCTION KEYWORD NOT FOUND IN ENVIRMENT VARIABLE PLEASE ADD")
    
    #ALso check that the taget names are all the same
    CheckTargets.CheckTargName()
    #and that the exposure time > 0
    CheckExposureTime.CheckExposureTime()
    
    #1. Run the cte correction on the data
    cte.cte_correct( idl=idl )

    #2. Flat field the image with calacs
    run_calacs.run_calacs( )
    
    #3. Get all the bands that are involved
    hst_filters = ghb.get_hst_band()

    #4. Prepare for drizzling by moving some jref files back
    #   to original name
        
    if type(search_rad) == float:
        search_rad = np.zeros(len(hst_filters))+search_rad

    if type(thresh) == float:
        thresh = np.zeros(len(hst_filters))+thresh


    for iCount, iFilter in enumerate(hst_filters):
        
        fileobj = open( iFilter+'.lis', 'rb')
        flts = [ iFlt[0:13]+'_flt.fits' for iFlt in fileobj ]
        drizzle.drizzle( 'USING FILES', cluster, iFilter,
                         files=flts,
                         jref_path=jref_path, single=single,
                         search_rad=search_rad, thresh=thresh,
                         pixel_scale=pixel_scale,
                         drizzle_kernel=drizzle_kernel,
                         wht_file=wht_file)




    
class Logger(object):
    def __init__(self, filename="Default.log"):
        self.terminal = sys.stdout
        os.system('rm -fr '+filename)
        self.log = open(filename, "a")

    def write(self, message):
        self.terminal.write(message)
        self.log.write(message)


if __name__ == '__main__':
    method_name, cluster = sys.argv[0], sys.argv[1]
    main(cluster)
