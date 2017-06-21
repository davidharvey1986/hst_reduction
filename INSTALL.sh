#!/bin/bash
virtual_env=${1}
if [ -d "${virtual_env}" ]; then
   echo ${virtual_env}' directory already exists, do not clobber'
   exit
fi
virtualenv -p /usr/bin/python2.7 ${virtual_env}
cd ${virtual_env}
ROOT_DIR=${PWD}
cd ${ROOT_DIR}/bin
unset PYTHONPATH
source activate
echo $PYTHONPATH
which pip
which python
./pip install ipython
./pip install numpy==1.11.0
./pip install stsci.distutils
./pip install stscipython
./pip install pyfits==3.1.6
cp -fr /Users/DavidHarvey/Library/Code/python/hst_reduction/dist/pyHST-0.0.1.tar.gz ${ROOT_DIR}
cd ${ROOT_DIR}
tar -xvf pyHST-0.0.1.tar.gz
cd pyHST-0.0.1
python setup.py install
cd ${ROOT_DIR}
cp ${ROOT_DIR}/lib/python2.7/site-packages/pyHST-0.0.1-py2.7.egg/pyHST/stsci_patches/fileutil.py ${ROOT_DIR}/lib/python2.7/site-packages/stsci/tools/
cp ${ROOT_DIR}/lib/python2.7/site-packages/pyHST-0.0.1-py2.7.egg/pyHST/stsci_patches/mutil.py ${ROOT_DIR}/lib/python2.7/site-packages/stwcs/distortion/mutil.py
echo -en "\033[36m"
echo 'Please do the following'
echo -en "\033[31m"
echo 'export PATH='${ROOT_DIR}'/bin:'${ROOT_DIR}'/lib/python2.7/site-packages/pyHST-0.0.1-py2.7.egg/pyHST/calacs:$(getconf PATH)'
echo 'source '${ROOT_DIR}'/bin/activate'
echo 'unset PYTHONPATH'
echo -en "\033[0m"


