'''
A script to check if the required reference files are available
And then to download missing ones.

'''


import os as os
import pyfits as py


def get_acs_reffiles( cte_file, ext='all',
                    acs_reffiles_location = 'ftp://ftp.stsci.edu/cdbs/jref/',
                      add_jref=True ):
    '''
    For the input acs_file i will look in the header and check
    for the required calibration files

    And then download them from
    https://hst-crds.stsci.edu/browse

    Also need save the files with a precursing 'jref' on the start so calacs recognises tehm

    INPUT : CTE_FILE : A string of the name of a cte file that has all the header information
                       regarding the reference files to use

    OPTIONAL INPUT: EXT : the file extension to specifially download. If not set
                          defaults to 'all', and will download all extensions

    UPDATE :
       1. Scraping the file from  'ftp://ftp.stsci.edu/cdbs/jref/' using curl
          instead of 'https://hst-crds.stsci.edu/browse' using wget -m -nd -r -A.fits
          which is much cleaner. Only, if it fails because this is not a exhaustive database
          we should bare in mind

    '''

    print 'Getting ACS referenes files for ',cte_file
    header = py.open( cte_file )[0].header
    
    req_calibration_files = []
    for i in header.keys():
        if header[i] == True:
            continue
        if 'jref' in str(header[i]):
            get_file = str(header[i])[5:]
            get_file_ext = get_file.split('_')[1][:3]

            if add_jref:
                save_file = os.environ['jref']+'/jref'+get_file
            else:
                save_file = os.environ['jref']+'/'+get_file

            if (ext == 'all') | (ext == get_file_ext):
                if not os.path.isfile( save_file ):
                    if not os.path.isfile( get_file ) :
                        print("FETCHING %s\n" %get_file)
                        os.system("curl -O "+acs_reffiles_location+"/"+get_file)
                        if not os.path.isfile(get_file):
                            raise ValueError('Error in obtaining the reference file')
                        os.system("mv "+get_file+" "+save_file)
                    else:
                        if add_jref:
                            os.system("mv "+get_file+" "+save_file)

                


        

                
