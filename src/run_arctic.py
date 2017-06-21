import multi_to_single_fits as mts
import pyfits as fits
import os as os

def run_arctic( image_name, outfile ):
    '''
    Take input raw file for ACS and divide into 
    difertent extensions. Run the programme and then
    remake the raw input file
    '''
    pre_cte_file = fits.open( image_name)
    for iExt in range(1,3):
        #First extract one of the extensions
        #as arctic has to do one at a time
        mts.main(image_name[:-5],iExt)
        
        outfile_ext = image_name[:-5]+'_'+str(iExt)+'.fits'
        #run arctoc command
        os.system( "arctic.sh arctic_in.fits "+outfile_ext)
        #opent he newly formed file
        ext = fits.open( outfile_ext )
        #and change the dat in the original raw file
        pre_cte_file['SCI', iExt].data = ext[0].data
        os.system( "rm -fr *A.fits")
        os.system( "rm -fr *B.fits")
        os.system( "rm -fr *C.fits")
        os.system( "rm -fr *D.fits")
    #once completed writeto the new outfile name
    pre_cte_file.writeto( outfile, clobber=True )


    

    
    
