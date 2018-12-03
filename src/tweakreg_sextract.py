'''
This script will run sextractor over the images so that it generates
catalogues that will be used in TweakReg in the alignment process

'''
import pysex as sex
import os as os

def tweakreg_sextract( files_to_sextract, catfile_name,
                       sexfile_dir=None):
    '''
    Systematically loop through each file and sextract the sources
    and write them in a catalogue

    It has to output the catalogue in pixels using the files tweak.sex
    and tweak.param
    
    INPUT : files_to_sextract : a python list of file names to source extract
            catfile_name : name of the file containing the image and catalogue names
    
    OUTPUT : A source catalogue for each 
    '''
    if sexfile_dir is None:
        sexfile_dir = '/'.join(os.path.abspath(__file__).\
                                   split('/')[:-1])+'/tweak_sex/'
                                   
    catfile = open( catfile_name, "wb")

    for iFile in files_to_sextract:
        outcat_name = iFile[:-5]+'_sex.cat'
        conf_file = sexfile_dir+'tweak.sex'
        filter_name = sexfile_dir+'gauss_5.0_9x9.conv'
        starnnw_name = sexfile_dir+'default.nnw'
        param_file =  sexfile_dir+'tweak.param'
        
        sexCat = sex.run(   iFile,
                            conf_file=conf_file,
                            param_file=param_file, \
                            conf_args={'CATALOG_NAME':outcat_name,
                                       'FILTER_NAME':filter_name,
                                       'STARNNW_NAME':starnnw_name})

        catfile.write("%s %s\n" % (iFile, outcat_name) )


        
def ref_sex( refimage, sexfile_dir=None):
    
    '''
    PURPOSE : TO SEXTRACT THE COORDINATES OF THE OBJECTS IN
              FOR THE REFERENCE CATALOGUE


    '''
    if sexfile_dir is None:
        sexfile_dir = '/'.join(os.path.abspath(__file__).\
                                   split('/')[:-1])+'/tweak_sex/'
                                   
    conf_file = sexfile_dir+'tweak_wcs.sex'
    filter_name = sexfile_dir+'gauss_5.0_9x9.conv'
    starnnw_name = sexfile_dir+'default.nnw'
    param_file =  sexfile_dir+'tweak_wcs.param'
        
    sexCat = sex.run(   refimage,
                        conf_file=conf_file,
                        param_file=param_file, \
                        conf_args={'CATALOG_NAME':'reference.cat',
                                    'FILTER_NAME':filter_name,
                                    'STARNNW_NAME':starnnw_name})
        
   
