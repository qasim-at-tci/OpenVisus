#!/bin/bash
set -e 
set -x  

uname -m

GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || true)

# todo: enable also for arm64
VISUS_MODVISUS=0
if [[ '${PYTHON_VERSION}' == '3.7' && '${VISUS_GUI}' == '0' && '${PLATFORM}' == 'linux/amd64' ]] ; then
  VISUS_MODVISUS=1
fi

mkdir -p build 
cd build
cmake \
  -DPython_EXECUTABLE=`which python${PYTHON_VERSION}` \
  -DQt5_DIR=${Qt5_DIR} \
  -DVISUS_GUI=${VISUS_GUI}  \
  -DVISUS_SLAM=${VISUS_GUI} \
  -DVISUS_MODVISUS=${VISUS_MODVISUS}  \
  ../
  
make -j
make install

export PYTHONPATH=$PWD/Release
python${PYTHON_VERSION} -m OpenVisus configure || python${PYTHON_VERSION} -m OpenVisus configure  # segmentation fault problem
python${PYTHON_VERSION} -m OpenVisus test
python${PYTHON_VERSION} -m OpenVisus test-gui || true # this can fail because the current OS is too old to support python pyqt (example C++ using qt5.12, python installed 5.12 but python needs GLIB with a version newer than Centos6 that is the OS used for compiling... don't care right now)
unset PYTHONPATH

if [[ "${GIT_TAG}" != "" ]] ; then
  pushd Release/OpenVisus
  python${PYTHON_VERSION} -m pip install setuptools wheel twine 1>/dev/null 
  python${PYTHON_VERSION} setup.py -q bdist_wheel --python-tag=cp${PYTHON_VERSION:0:1}${PYTHON_VERSION:2:1} --plat-name=${WHEEL_PLATFORM_NAME}
  python${PYTHON_VERSION} -m twine upload --username ${PYPI_USERNAME} --password ${PYPI_PASSWORD} --skip-existing  "dist/*.whl" 
  popd
  
  if [[ "${VISUS_MODVISUS}" == '1' ]] ; then
    sleep 30 # give time pypi to get the pushed file
    pushd ../Docker/mod_visus
    echo ${DOCKER_TOKEN} | docker login -u=${DOCKER_USERNAME} --password-stdin
    docker build --tag visus/mod_visus:$TAG --tag visus/mod_visus:latest --build-arg TAG=$TAG .
    docker push visus/mod_visus:$TAG
    docker push visus/mod_visus:latest
    popd
  fi
fi

