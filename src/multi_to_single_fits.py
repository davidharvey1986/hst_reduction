import os
import sys
import pyfits as pyfits
import subprocess as sp

def main( file_name_load, extension ):

    arctic_dir = os.getcwd()+'/'

    hdulist = pyfits.open(arctic_dir+file_name_load+'.fits')  # open the fits file & header information


    header = hdulist[0].header
    data = hdulist['SCI', extension].data  # copy fits data to data array for loading

    new_hdr = pyfits.Header()
    new_hdr['DATE'] = header['DATE-OBS']
    new_hdr['BUNIT'] = 'ELECTRONS'

    # Write the data on disk in a FITS file
    basename_in = file_name_load+"_in.fits"
    infilename = os.path.join(arctic_dir, basename_in)
    basename_out = file_name_load+"_out.fits"
    outfilename = os.path.join(arctic_dir, basename_out)

    hdu = pyfits.PrimaryHDU(data, new_hdr)
    hdu.writeto('arctic_in.fits', clobber=True)
