import pyfits as fits
import glob as glob
import numpy as np
import os as os
def CheckTargName( sort=False):
    '''
    This script is to check that all the raw
    files that I am drizzle come from the same
    target. 

    '''
    
    
    RawFitsFiles = np.array(glob.glob('j*_raw.fits'))

    TargNames = []
    
    for iFits in RawFitsFiles:

        RawFits = fits.open(iFits)
        TargNames.append(RawFits[0].header['TARGNAME'])
        
        print('%s: %s' % (iFits, RawFits[0].header['TARGNAME']))

    TargNames = np.array(TargNames)
    if not np.all(np.array(TargNames) == TargNames[0]):
        sort = raw_input('Sort the files by TargName? ')
        
        if sort == 'yes':
            UniqueTargNames = np.unique(TargNames)
            
            for iTargName in UniqueTargNames:
                
                iTargExpFile = RawFitsFiles[ iTargName == TargNames ]
                
                for iFits in iTargExpFile:
                    if not os.path.isdir(iTargName):
                        os.system('mkdir '+iTargName)
                        
                    ExpID = iFits.split('_')[0]
                    
                    os.system('mv '+ExpID+'* '+iTargName)
            

            raise ValueError('Not all exposures have the same target')    
        else:
            sort = raw_input("Continue anyway? ('y' or 'n')")
            if sort == 'y':
                return
            else:
                raise ValueError('Not all exposures have the same target')    
    
    
    
