import sys,os,string,glob,subprocess

from setuptools import setup,Extension
from setuptools.command.build_ext import build_ext
from setuptools.command.install import install

import numpy

long_description = """\
This module uses the RRG method to measure the shapes of galaxies
in Hubble Space Telescope data
"""
#python setup.py register -r pypi
#sudo python setup.py sdist upload -r pypi

version='0.0.1'
         
    
INCDIRS=['.']

packages = ['pyHST','asciidata']
package_dir = {'pyHST':'./src',
               'asciidata':'./lib/asciidata'}
package_data = {'pyRRG': ['tweak_sex/*','bin/*']}


setup   (       name            = "pyHST",
                version         = version,
                author          = "David Harvey",
                author_email    = "david.harvey@epfl.ch",
                description     = "pyHST module",
                license         = 'MIT',
                packages        = packages,
                package_dir     = package_dir,
                package_data    = package_data,
                url = 'https://github.com/davidharvey1986/pyRRG', # use the URL to the github repo
                download_url = 'https://github.com/davidharvey1986/pyHST/archive/'+version+'.tar.gz',
                install_requires=['pyfits==3.1.6',\
                                      'numpy==1.11.0',
                                      'stscipython'.\
                                      'stsci.distutils'],                          
        )


