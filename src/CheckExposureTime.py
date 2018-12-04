'''
For some reason, some of the HST images often have 0 exposure time
this means that everything gets screwed up.

So I need to check for these and raise flags

'''


import pyfits as fits
import glob as glob
import numpy as np
import os as os

def CheckExposureTime( sort=False):
    '''
    This script is to check that all the raw
    files that I am drizzle come from the same
    target. 

    '''
    RawFitsFiles = np.array(glob.glob('j*_raw.fits'))

    ExposureTime = []
    
    for iFits in RawFitsFiles:

        RawFits = fits.open(iFits)
        ExposureTime.append(RawFits[0].header['EXPTIME'])
        if RawFits[0].header['EXPTIME'] == 0:
            print('Failed Exposure Time (%s: %s)' \
                    % (iFits, RawFits[0].header['EXPTIME']))

    if np.any(np.array(ExposureTime)) == 0:
        raise ValueError("Found exposures with 0 exposure time, please remove")
