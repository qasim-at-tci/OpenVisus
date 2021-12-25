#!/bin/bash

set -e
set -x

BUILD_DIR=${BUILD_DIR:-build}
PYTHON_VERSION=${PYTHON_VERSION:-3.8}
Qt5_DIR=${Qt5_DIR:-/opt/qt512}
VISUS_GUI=${VISUS_GUI:-1}
VISUS_SLAM=${VISUS_SLAM:-1}
VISUS_MODVISUS=${VISUS_MODVISUS:-1}

PY=`which python${PYTHON_VERSION}`

mkdir -p ${BUILD_DIR} 
cd ${BUILD_DIR}
cmake -DPython_EXECUTABLE=${PY} -DQt5_DIR=${Qt5_DIR} -DVISUS_GUI=${VISUS_GUI} -DVISUS_SLAM=${VISUS_SLAM} -DVISUS_MODVISUS=${VISUS_MODVISUS} ../

make -j 
make install

export PYTHONPATH=$PWD/Release 

# this is needed to fix rpaths before exiting from docker
# I don't care if it fails
${PY} -m OpenVisus configure || echo 'configure failed but should be fine' 

# this should pass the test
${PY} -m OpenVisus test 

# this can fail because the OS (like Centos 6) does not fully support pyqt
${PY} -m OpenVisus test-gui || echo 'test-gui failed but should be fine'



