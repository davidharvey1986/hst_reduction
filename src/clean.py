'''
This script is designed to clean all the superfluous 
files after the reduciton

'''


import os as os
import glob as glob

def clean( path='./', raw=False, jref=False):
    os.system('rm -fr *tmp*')
    os.system('rm -fr *asn*')
    os.system('rm -fr *coo*')
    os.system('rm -fr *match*')
    print 'cleaning files'
    os.system('rm -fr *list*')
    os.system('rm -fr *cat*')
    os.system('rm -fr *sci1*')
    os.system('rm -fr *sci2*')
    os.system('rm -fr *mask*')
    os.system('rm -fr *ctx*')
    os.system('rm -fr *med*')
    os.system('rm -fr *single_*')
    os.system('rm -fr *flc*')
    os.system('rm -fr *spt*')
    os.system('rm -fr *trl*')
    os.system('rm -fr *tra')
    if jref:
        os.system('rm -fr jref*')
    if raw:
        os.system('rn -fr *raw*')
    for i in glob.glob(path+'/keep/*'):
        keepFile = i.split('/')[-1].split('_')[0]
        os.system('rm -fr '+keepFile+'_*')
