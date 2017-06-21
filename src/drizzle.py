""" drizzle.py

Script to run pyraf from the command line and multidrizzle files

Author : David Harvey
Date : 13/11/2011

"""
import sys
import argparse as ap
from stwcs import updatewcs
import argparse
import numpy as np
import csv as c
import os
import glob
import drizzlepac 
from  drizzlepac import astrodrizzle
from drizzlepac import tweakreg
from drizzlepac import tweakback
from subprocess import call
import tweakreg_sextract as tweaksex
import pyfits as fits

def drizzle(input_filename, cluster, filter, \
            combine_type='iminmed', \
            wcs_update=True, individual=True, \
            single=False, outputfilename=None,
            jref_path='../', search_rad=1.0, thresh=1.0,
            files=None, drizzle_kernel='square', pixel_scale=0.03):

    '''
    PURPOSE : TO STACK TOGETHER IMAGES FROM DIFFERENT EPOCHS
              AND DRIZZLE THEM TOGETHER


    INPUTS : INPUTFILENAME: CAN EITHER BE A SINGLE FILE, OR
             A LIST USING A WILDCARD E.G *FLT.FITS

             OUTPUTFILENAME : THE NAME OF THE DRIZZLED OUT
             PUT FILENAME


    METHOD :

    1. FIRST IT NEEDS TO UPDATE THE WCS OF EACH INDIVIDUAL
       EXPOSURE

    2. ONCE IT HAS DONE THIS, IT WILL GET THE DATES OF ALL THE
       OBSERVATIONS AND DRIZZLE TOGETHER THOSE THAT ARE FROM THE
       EXACT SAME DATE
       ONCE IT HAS DONE THIS IT WILL TWEAK THESE DRIZZLED IMAGES

    3. THEN USING THE TWEAK OPERATION IN THE HEADER OF THESE
       DRIZZLED FILES IT WILL TWEAKBACK TO THE FLT IMAGES

    4. THEN IT WILL DRIZZLED TOGETHER ALL THE FLT IMAGES


    ARGUMENT:
      - input_filename :  A STRING CONTAINING THE FILES TO DRIZZLE, ALMOST
                          ALWAYS '*FLT.FITS' (if want a list use 'file')
      - cluster, filter : STRINGS CONTAINIGN THE CLUSTER NAME AND FILTER TO DRIZZLE

    KEYWORDS :
    
      - combine_type : HOW IMAGES ARE COMBINED DEFAULT IS 'iminmed', \
      - wcs_update : DO I WANT TO UPDATE THE WCS HEADERS? DEFAULT=True
      - individual : DO I WANT TO DRIZZLE EACH OBS RUN INDIVUALLY AND TWEAKBACK DEFAILT =True, \
      - single : DO I WANT TO DRIZZLE EACH IMAGE ONTO ITS ON FRAME FOR PURPOSE OF PSF EST DEF=False):
      - outputfilename : the string of the output file. If not given the name defauilts to
                         CLUSTER_FILTER_drz_sci.fits
      - jref_path : string, the location of the calibration files for distortion etc
      - search_rad : float : the size in pixels of tweakreg when it searches for overlapping sources
                             to align objects (keyword in TweakReg)
      - threshold : the threshold in signal to noise for sources when alligning exposures (keyword in TweakReg)
      - files : a python list of files to be drizzled together, if none it will use the input_filename

      
    UPDATE : 15/01/2014 : NEW PIPELINE
             07/10/2014 : V2 : CHANGE FROM OBSERVATION DATE TO OBSERVATION RUN
             25/11/2016 : V3 : Updatewcs just the singluar version now, which should be okay
                               with all data, but a note of worry.


    NOTE:
        IF UPDATEWCS fails with 'HDUList has attribute' (or something liek this)
        then the bug lies within STSCI, from the fact that it imports two different
        versions of pyfits, its own and the one that may exist on your compiuter.
    
    '''

    if fits.__version__ != '3.1.6':
        raise ImportError('Not the correct version of pyfits, needs 3.1.6')
    if np.__version__ != '1.11.0':
        raise ImportError('Not the correct version of numpy, needs 1.11.0')


    if files is None:
        files = glob.glob( input_filename )
    else:
        input_filename = ','.join(files)
        
    if single:
        call(["mkdir", "singles"])
        
        for iflt in files:
            iDrz = iflt.split("_")[0]
            drizzle( iflt, iDrz, filter, \
                     outputfilename=iDrz,
                     jref_path=jref_path)
            call(["mv", iDrz+"_drz_sci.fits","singles"])

            
   
    if len(files) == 1:
        combine_type='minimum'
        
    #OUTPUTFILENAME
    if outputfilename is None:
        outputfilename = cluster+'_'+filter
        
    
    #SETUP ENVIRONMENT VARIABLE
    os.environ['jref'] = jref_path
    os.environ['iref'] = '../'



    #1. FIRST UPDATE THE WCS
    #------------------------------------------
    if wcs_update:
        update_wcs( input_filename, files=files )
    
    
    #2. NOW GET THE OBSERVATION DATES AND DRIZZLE THEM TOGETHER
    #--------------------------------------------------------------------------
    print 'Getting dates of the Observations'
    #obsDates, fltList = date_list( input_filename)
    obsRun, fltList = obs_name( input_filename, files=files )

       
    uniqueObs = np.unique(np.array(obsRun))

    
    if len(uniqueObs) > 1 and individual is True:
        drizzle_fields( obsRun, fltList, cluster, filter,
                        thresh=thresh, search_rad=search_rad )
    else:
        print 'All observations taken on the same run'
    #4. NOW DRIZZLE TOGETHER ALL THE TWEAK FLT IMAGES


    astrodrizzle.AstroDrizzle( input_filename, \
                                output=str(outputfilename), \
                                final_wcs=True, \
                                final_scale=pixel_scale, \
                                final_pixfrac=0.8, \
                                combine_type=combine_type, \
                                final_kernel=drizzle_kernel)
                                
    


  
    if single:
        call(["mv", "singles/*", "."])
    '''
    FOR REFERENCE:

    
    TWEAKREG INPUTS
    ----------------------------------------------------------
    str(input_filename)
    residplot='both'
    see2dplot=True, 
    writecat=False, 
    catfile='catfile'
    xcol=1, ycol=2, fluxcol=3,
    searchrad=np.float(search_rad)
    fitgeometry='shift')
    refimage=str(refimage))
        
    ASTRODRIZZLE INPUT PARS
    --------------------------------------------------------
    str(input_filename),
    output=str(outputfilename), \
    final_wcs=True, \
    final_scale=0.03, \
    final_pixfrac=0.8, \
    combine_type='imedian', \
    final_refimage='ref_image_drz_sci.fits'
    '''
    
def update_wcs( input_filename, files=None):
    '''
    PURPOSE : TO UPDATE THE WCS USING THE DRIZZLEPAC

    NOT SO EASY AS DIFFERENT AGED OBSERVATIONS APPEARS TO NEED DIFFERENT
    UPDATE WCS
    '''
        
    #If i am updating various flt files some new some old thne
    #if new ones use a different module.
            
    #loop over inidivudla flt not *flt.fits


    if files is None:
        files = glob.glob(input_filename)
    
    for iFile in files:
        updatewcs.updatewcs(iFile)



def drizzle_fields( obsDates, fltList, cluster, filter, search_rad=1, thresh=1):
    '''
    PURPOSE : IF THERE ARE OBSERVATIONS FROM DIFFERENT DATES / OBSRUNS
    THEN DRIZZLE THE DATES THAT ARE THE SAME TOGETHER
    THEN TWEAK THEM TO ONE REFERENCE DRIZZLE IMAGE
    TWEAK BACK TO THE FLT FITS

    INPUTS : OBSDATES : CAN BE ANY UNIQUE IDENTIFIER TO NAME OF THE RUN
                        OR DATE
    
    thresh=1.0
    search_rad=1.0 #Often this parameter is too big if the images hardly overlap. Keep at 1 if limited sources
    '''
    outputfilename = cluster+'_'+filter

    uniqueObs = np.unique(np.array(obsDates))

    print 'MORE THAN ONE OBSERVATION DATE/RUN SO DRIZZLING INDIVIDUALLY'
    print uniqueObs

    call(["mkdir", "keep"])
        

    for iDate in uniqueObs:
        obsDrizzle = np.array(fltList)[ np.array(obsDates) == str(iDate) ]
        drizzleString = ",".join(obsDrizzle)
        print iDate
        print obsDrizzle

        if not os.path.isfile("keep/"+str(iDate)+"_drz_sci.fits"):
            astrodrizzle.AstroDrizzle(drizzleString, \
                                        output=str(iDate), \
                                        final_wcs=True, \
                                        final_scale=0.03, \
                                        final_pixfrac=0.8, \
                                        combine_type='iminmed')
                                        
            call(["cp",str(iDate)+"_drz_sci.fits","keep"])
    
        else:
            call(["cp","keep/"+str(iDate)+"_drz_sci.fits","."])

            
            
            
    #3. NOW TWEAK EACH DRIZZLED IMAGE
    #-----------------------------------------

    #First sextract them using tweak_sextract

    drzList=[]
    for iDate in uniqueObs:
        drzList.append(str(iDate)+"_drz_sci.fits")
        
    try:
        drzList.remove(str(outputfilename)+'_drz_sci.fits')
    except:
        print 'its okay, cluster drizzle doesn exist'

                    
       
    

    #Run sextractor on the images
    #tweaksex.tweakreg_sextract(drzList,'catfile')
    refDate=obsDates[1]#
    refimage=drzList[1]#
    drzString= ",".join(drzList)


    
    tweaksex.ref_sex( refimage )
    
    tweakreg.TweakReg(drzString, \
                        residplot='both', \
                        see2dplot=True, \
                        threshold=np.float(thresh), \
                        searchrad=np.float(search_rad), \
                        fitgeometry='rscale', updatehdr='True', \
                        refimage=refimage, 
                        catfile='catfile', \
                        xcol=1, ycol=2, fluxcol=3, \
                        minobj=2, \
                        refcat='reference.cat', \
                        refxcol=1, refycol=2, rfluxcol=3)
                          
    for iDate in uniqueObs:
        if iDate != obsDates:
            TweakFLT= np.array(fltList)[ np.array(obsDates) == str(iDate) ]
        tweakString = ",".join(TweakFLT)
        print tweakString
        tweakback.tweakback( str(iDate)+'_drz_sci.fits', \
                                input=tweakString )



def obs_name( input_filename, files=None ):
    '''
    PURPOSE : TO GET THE OBSERVATION RUN NAME (DATA SET NAME)
             WHICH IS THE FIRST 6 CHARACATERS

    INPUTS : THE NAME OF ALL THE IMAGES

    OUTPUTS : THE REMOVED LAST 3 DIGITS TO GIVE THE NAME OF
              THE OBS RUN


    '''
    fltList = []
    obsRun = []

    if files is None:
        files = glob.glob( os.path.join('',str(input_filename) ) )
        
    for infile in files:
        #print "The date of" + infile + " is "+  im.image_date( infile )
        fltList.append( infile ) 
        obsRun.append( infile[:6] )


    return obsRun, fltList



    

if __name__ == '__main__':
    
    method_name, arg_strs = sys.argv[0], sys.argv[1:]
    
    input_filename = arg_strs[0]
    cluster = arg_strs[1]
    filter = arg_strs[2]
    kwargs={}
    for arg in arg_strs:
        if arg.count('=') == 1:
            key, value = arg.split('=')
            kwargs[ key ]  = value

    
    drizzle(input_filename, cluster, filter, single=True, **kwargs)
