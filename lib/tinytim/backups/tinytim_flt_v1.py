import drizzlepac 
import numpy as np
import ipdb as pdb
import glob as glob
import tinytim as tinytim

def tinytim_flt( cluster ):
    '''

    A function that creates fake flt files that are popualted
    with stars at the positions of the objects given in a catalogue

    Each flt will have the same header as the true flt from the
    data

    Will output N FLT images of PSFS with focus positions as
    determined by RRG_psf_cor

    So therefore requries some pre working

    1. Drizzled image of the cluster and reduced FLT files
       in the folder

           /Users/DavidHarvey/Documents/Work/CLASH_PSF/CLUSTER/FILTER

    2. A catalogue of object positions at which to calcualte the PSF
       named

          CLUSTER_clash.cat

    3. A file called FocusArray.txt that is produced during the shape
       measurement process of rrg. This file contains N FLT lines with
       image name (minus any extension such as _flt.fits) and then the
       estiamted focus positions of HST ACS at the time of obseravtion


    4. Once I have these in the correct folders, it should be good to go.

    REQUIRES : TINYTIM, TINYTIM_CREATE.PRO, DRIZZLEPAC

    '''

    
    rootDir = '/Users/DavidHarvey/Documents/Work/CLASH_PSF/'
    dataDir = rootDir+'/clusters/'+cluster

    filters = glob.glob(dataDir+'/*')
    ra_hms = []
    dec_hms = []
    for iFilter in filters:
        filter_string = "'"+iFilter.split("/")[-1]+"'"
    
        images, focus = np.loadtxt(iFilter+'/FocusArray.txt', \
                                dtype=('str'), unpack=True )

        ra, dec = np.loadtxt( iFilter+'/'+cluster+'_clash.cat', \
                                usecols=(1,2), unpack=True )


        outputDir = iFilter+'/TinyTim/'
        
        for iImage in xrange(len(images)):
            skyparfile = "sky2xy.par"
            skypar = open(skyparfile,"wb") 
            for i in xrange(len(ra)):
                i_ra_hms, i_dec_hms = drizzlepac.wcs_functions.ddtohms(ra[i],dec[i],verbose=False)
                skypar.write(str(i_ra_hms)+"   "+str(i_dec_hms)+"\n")
            skypar.close()
            
            #chip1
            FLT = iFilter+'/'+images[iImage]+'_flt.fits[sci,1]'
            x_chip1, y_chip1 =  drizzlepac.skytopix.rd2xy( FLT, coordfile=skyparfile)

            #chip2
            FLT = iFilter+'/'+images[iImage]+'_flt.fits[sci,2]'
            x_chip2, y_chip2 =  drizzlepac.skytopix.rd2xy( FLT, coordfile=skyparfile,\
                                                           verbose=False)

            x = np.append( x_chip1[ y_chip1 < 2048 ], x_chip2[ y_chip1 > 2048 ])
            y = np.append( y_chip1[ y_chip1 < 2048 ], y_chip2[ y_chip1 > 2048 ]+2048)
            tinytim.run( x, y, focus_range=focus[iImage], \
                            pixel_scale=0.03, \
                            output_dir="'"+outputDir+"'", \
                            filter=filter_string,\
                            raw=1, fitsname="'"+images[iImage]+"_TT'",\
                            exact_position=1)
