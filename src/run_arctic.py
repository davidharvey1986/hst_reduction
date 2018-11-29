import multi_to_single_fits as mts
import pyfits as fits
import os as os

def run_arctic( image_name, outfile ):
    '''
    Run te script by James
    '''

    os.command('arctic_acs.sh '+image_name)

    imageID = image_name.split('_')[0]
    GeneratedOutfile=imageID+'_cte.fits'
    DesiredFileName = imageID+'_cte_raw.fits'
    
    os.command('mv '+GeneratedOutfile+' '+DesiredFileName)


    

    
    
