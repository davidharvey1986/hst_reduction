import drizzlepac 
import numpy as np
import ipdb as pdb
import glob as glob
import tinytim as tinytim
import tinytim_change_header as tt_header
import drizzle_tinytim as driz_TT
import nearest_neighbour as NN

def tinytim_flt( cluster, ra=None, dec=None, tweaked=False ):
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

    KEYWORDS :
        RA, DEC : COODAITNES GIVEN BY USER TO USE, IF NONE
                  IT WILL LOOK FOR A CATALOGUE
                  
        TWEAKED : USE IMAGES THAT HAVE BEEN TWEAKED TO CREATE
                  PSFS THIS WAY THEY CAN BE DRIZZLED IMEDIATELY
                  ALTHOUGH THIS REQUIRES THE ENTIRE FIELD OF PSGS
                  TO BE ALREADY DRIZZLED AND HAVE EXISTING FILES
                  IN THE PRE-REQUISITE PATHS

    '''

    
    rootDir = '/Users/DavidHarvey/Documents/Work/CLASH_PSF/'
    dataDir = rootDir+'/clusters/'+cluster

    filters = glob.glob(dataDir+'/*')
    ra_hms = []
    dec_hms = []
    for iFilter in filters:
        filter_string = iFilter.split("/")[-1]
        images, focus = np.loadtxt(iFilter+'/FocusArray.txt', \
                                dtype=('str'), unpack=True )

        if ra is None or dec is None:
            ra, dec = np.loadtxt( iFilter+'/'+cluster+'_clash.cat', \
                                    usecols=(1,2), unpack=True )

        outputDir = iFilter+'/TinyTim/'
        
        nImages = len(focus)
        
        for iImage in xrange(nImages):
            if nImages == 1:
                image_use = images
            else:
                image_use = images[iImage]
                
            fits =  iFilter+'/'+image_use+'_flt.fits'
            print fits
            x, y = deg2pix_flt( fits, ra, dec)

            if len(x) == 0 or len(y) == 0:
                print 'No galaxies in field'
                continue
            tinytim.run( x, y, focus_range=focus[iImage], \
                            pixel_scale=0.03, \
                            output_dir="'"+outputDir+"'", \
                            filter="'"+filter_string+"'",\
                            raw=1, fitsname="'"+image_use+"_TT'",\
                            exact_position=1)



def postage_stamp( cluster, postage_size=80 ):
    '''
    Create postage stamps of FLTs

    To do this the plan is to take the positions of all
    the ra and dec, turn them into x and y
    
    Then find where the nearest neighbours are
    use only those stars that are far enough away from others that
    they can be used.

    With those objects that have close neighbours, I will choose
    one of the neighbours and append that to the fits image

    Then i will loop back around and do the other pair in that image

    And if it is a triplet then move back around and creat that one.

    So I will out put many fits images, each one where the closest neighbour
    is greater than the required distance
    '''
    
    rootDir = '/Users/DavidHarvey/Documents/Work/CLASH_PSF/'
    dataDir = rootDir+'/clusters/'+cluster

    filters = glob.glob(dataDir+'/*')
    ra_hms = []
    dec_hms = []
    for iFilter in filters:
        filter_string = iFilter.split("/")[-1]
        images, focus = np.loadtxt(iFilter+'/FocusArray.txt', \
                                dtype=('str'), unpack=True )

        ra, dec = np.loadtxt( iFilter+'/'+cluster+'_clash.cat', \
                                usecols=(1,2), unpack=True )

        outputDir = iFilter+'/TinyTim/'
        
        for iImage in xrange(len(images)):
            fits =  iFilter+'/'+images[iImage]+'_flt.fits'
            
            x_todo, y_todo = deg2pix_flt( fits, ra, dec)
            for j in xrange(3):
                x_drizzle=np.array([])
                y_drizzle=np.array([])
                for i in xrange(3):
                    x_chose, y_chose, x_todo, y_todo = \
                    pick_pairs( x_todo, y_todo, postage_size=postage_size, \
                                pair=2)
                    x_drizzle = np.append(x_drizzle, x_chose)
                    y_drizzle = np.append(y_drizzle, y_chose)
                    distance, closest_index = NN.nearest_neighbour(x_drizzle, y_drizzle)
                    spaced = np.sum( np.ones(len(distance[distance > postage_size])))

                    print spaced
                    x_chose, y_chose, x_todo, y_todo = \
                    pick_pairs( x_todo, y_todo, postage_size=postage_size, pair=1)
                            
                    x_drizzle = np.append(x_drizzle, x_chose)
                    y_drizzle = np.append(y_drizzle, y_chose)
                
                    distance, closest_index = NN.nearest_neighbour(x_drizzle, y_drizzle)
                    spaced = np.sum( np.ones(len(distance[distance > postage_size])))
                print spaced

                
                          
            pdb.set_trace()

def pick_pairs( x, y, postage_size=None, pair=2):
    distance, closest_index = NN.nearest_neighbour(x, y)

    isolated_x = x[ distance > postage_size ]
    isolated_y = y[ distance > postage_size ]
    iso_index = np.arange(len(distance))[ distance > postage_size ]
    cramped_index = closest_index[  distance < postage_size ]


    #DEAL WITH THE PAIRS
    ispair = closest_index[closest_index]-np.arange(len(x))
    ispair_cramp = cramped_index[ispair[ cramped_index ] == 0]

    #first_pair = np.delete(ispair_cramp, 


    pdb.set_trace()
    x_cramped_pairs = x[ un_cramped[ num_un == pair ] ]
    y_cramped_pairs = y[ un_cramped[ num_un == pair ] ]
            
    distance_pairs, closest_pair_index = NN.nearest_neighbour(x_cramped_pairs, y_cramped_pairs)
    
    isolated_x_first = x_cramped_pairs[ distance_pairs >  postage_size ]
    isolated_y_first = y_cramped_pairs[ distance_pairs >  postage_size ]
    cr_first_index = closest_pair_index[ distance_pairs <  postage_size ]

    first_iso_index =  un_cramped[ num_un == pair ][ distance_pairs >  postage_size ]

    x_first = np.append(isolated_x, isolated_x_first)
    y_first = np.append(isolated_y, isolated_y_first)
    #THEN WE MAKE THESE
    
            
    x_todo = np.delete(x, np.append(iso_index, first_iso_index))
    y_todo = np.delete(y, np.append(iso_index, first_iso_index))

    return x_first, y_first, x_todo, y_todo
    
def deg2pix( fits, ra, dec, coordfile=None):
    '''
    Given a fits file, convert from ra and dec in degrees to
    x and y pix

    '''

    if coordfile is None:
        coordfile = "sky2xy.par"
        skypar = open(coordfile,"wb") 
        for i in xrange(len(ra)):
            i_ra_hms, i_dec_hms = drizzlepac.wcs_functions.ddtohms(ra[i],dec[i],verbose=False)
            skypar.write(str(i_ra_hms)+"   "+str(i_dec_hms)+"\n")
        skypar.close()
    print fits
    return drizzlepac.skytopix.rd2xy( fits, coordfile=coordfile)


def deg2pix_flt( fits, ra, dec):
    '''
    Run the deg2pix function but for 2 separate chips
    concatenate them and remove any objects outside the chip
    '''
    
    #chip1
    x_chip1, y_chip1 =  deg2pix( fits+'[sci,1]', ra, dec)

    #chip2
    x_chip2, y_chip2 =  deg2pix( fits+'[sci,2]', ra, dec, coordfile="sky2xy.par")


    #Check that the objects lie within the chip and
    #which chip they are in
    inchip1 = (y_chip1 < 2048) & (y_chip1 > 0) & \
        (x_chip1 > 0) & (x_chip1 < 4096)
    inchip2 = (y_chip1 < 4096) & (y_chip1 > 2048) & \
        (x_chip2 > 0) & (x_chip2 < 4096)
            
    x = np.append( x_chip1[ inchip1 ], x_chip2[ inchip2 ])
    y = np.append( y_chip1[ inchip1 ], y_chip2[ inchip2 ]+2048)

    return x, y

    
