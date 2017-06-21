'''
get_hst_band.py

This script will take in the name of a cluster, 
look at the *_cte.fits and list those which are of
which spectroscopic band in order to descipher which
can be drizzled together and which cant.

Author : David Harvey
Date : March 21 2013 BIRTHDYA!

'''
import csv as c
import pyfits as py
import numpy as np

def get_hst_band( calacs_file_list='calacs.lis'):

    '''
    ARGUMENTS : None, although need to be in the directory
                where the flt files are

    KEYWORDS : calacs_file_list: a string that poitns to
               a file that contains the names of the
               files that went into flt files (and came
               out of the cte correction stage, i.e _cte.fits)
    OUTPUTS : N files, where N is the number of different hst
              bands that the observations were taken in
              Each file is called ${hst_filter}.lis
              and contains a list of exposures that correspond
              to this band
              

    '''
    #NOTE FOR NOW THIS IS DONE LIKE THIS BUT IN FUTURE
    #MAYBE DO BEFORE THE CTE SO SAVE TIME

    #Read in the list of cte files
    
    cte_obj = c.reader(open(calacs_file_list,"rb"),delimiter=' ')
    
    detector_ob = open("detector.lis","wb")
    detector_ob.write("Image Name Detector \n")

    images = []
    detector=[]
    #loop through each image and find the detector

    for image in cte_obj:

        for i in xrange(len(image)):

            hdulist = py.open(image[i])

            filter1 = hdulist[0].header["FILTER1"]
            filter2 = hdulist[0].header["FILTER2"]

            if filter1 == 'CLEAR1L':
                detector.append(filter2)
            else:
                detector.append(filter1)

            images.append(image[i])            
            detector_ob.write(str(image[i])+' '+str(detector[i])+'\n')

            
    filters = np.unique(detector)
    print filters

    for det in filters:
        detector_ob = open(str(det)+".lis","wb")
        for i in xrange(len(detector)):
            if detector[i] == det:
                detector_ob.write(str(images[i])+'\n')

             
    return filters
    

if __name__ == "__main__":
    get_hst_band()
