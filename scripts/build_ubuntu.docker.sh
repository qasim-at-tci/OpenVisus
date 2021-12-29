#!/bin/bash

set -e
set -x

GIT_TAG=`git describe --tags --exact-match 2>/dev/null || true`

# /////////////////////////////////////////////
# arguments

BUILD_DIR=${BUILD_DIR:-build_docker}
VISUS_GUI=${VISUS_GUI:-1}
VISUS_SLAM=${VISUS_SLAM:-1}
VISUS_MODVISUS=${VISUS_MODVISUS:-1}
PYTHON_VERSION=${PYTHON_VERSION:-3.8}
Qt5_DIR=${Qt5_DIR:-/opt/qt512}
PYPI_USERNAME=${PYPI_USERNAME:-}
PYPI_PASSWORD=${PYPI_PASSWORD:-}
ANACONDA_TOKEN=${ANACONDA_TOKEN:-}


# //////////////////////////////////////////////////////////////
function InstallConda() {
  pushd ~
  curl -L -O https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-$ARCHITECTURE.sh
  bash Miniforge3-Linux-$ARCHITECTURE.sh -b || true # maybe it's already installed?
  rm -f Miniforge3-Linux-$ARCHITECTURE.sh
  popd
}

# //////////////////////////////////////////////////////////////
function ActivateConda() {
   source ~/miniforge3/etc/profile.d/conda.sh || true # can be already activated
   conda config --set always_yes yes --set anaconda_upload no
   conda create --name my-env -c conda-forge python=${PYTHON_VERSION} numpy conda anaconda-client conda-build wheel 
   conda activate my-env
}

# ///////////////////////////////////////////////
function CreateNonGuiVersion() {
   mkdir -p Release.nogui
   cp -R   Release/OpenVisus Release.nogui/OpenVisus
   rm -Rf Release.nogui/OpenVisus/QT_VERSION $(find Release.nogui/OpenVisus -iname "*VisusGui*")
}

# ///////////////////////////////////////////////
function ConfigureAndTestCPython() {
   export PYTHONPATH=../
   $PYTHON   -m OpenVisus configure || true # this can fail on linux
   $PYTHON   -m OpenVisus test
   $PYTHON   -m OpenVisus test-gui || true # this can fail on linux
   unset PYTHONPATH
}

# ///////////////////////////////////////////////
function DistribToPip() {
   rm -Rf ./dist
   $PYTHON -m pip install setuptools wheel twine --upgrade 1>/dev/null || true
   $PYTHON setup.py -q bdist_wheel --python-tag=cp${PYTHON_VERSION:0:1}${PYTHON_VERSION:2:1} --plat-name=$PIP_PLATFORM
   if [[ "${GIT_TAG}" != "" ]] ; then
      $PYTHON -m twine upload --username ${PYPI_USERNAME} --password ${PYPI_PASSWORD} --skip-existing   "dist/*.whl" 
   fi
}

# //////////////////////////////////////////////////////////////
function ConfigureAndTestConda() {
   conda develop $PWD/..
   $PYTHON -m OpenVisus configure || true # this can fail on linux
   $PYTHON -m OpenVisus test
   $PYTHON -m OpenVisus test-gui    || true # this can fail on linux
   conda develop $PWD/.. uninstall
}

# //////////////////////////////////////////////////////////////
function DistribToConda() {
   rm -Rf $(find ${CONDA_PREFIX} -iname "openvisus*.tar.bz2") || true
   $PYTHON setup.py -q bdist_conda 1>/dev/null
   CONDA_FILENAME=$(find ${CONDA_PREFIX} -iname "openvisus*.tar.bz2" | head -n 1)
   if [[ "${GIT_TAG}" != "" ]] ; then
      anaconda --verbose --show-traceback -t ${ANACONDA_TOKEN} upload ${CONDA_FILENAME}
   fi
}


# /////////////////////////////////////////////////////////////////////////
# *** cpython ***

PYTHON=`which python${PYTHON_VERSION}`

ARCHITECTURE=`uname -m`
PIP_PLATFORM=unknown
if [[ "${ARCHITECTURE}" ==  "x86_64" ]] ; then PIP_PLATFORM=manylinux2010_${ARCHITECTURE} ; fi
if [[ "${ARCHITECTURE}" == "aarch64" ]] ; then PIP_PLATFORM=manylinux2014_${ARCHITECTURE} ; fi

mkdir -p ${BUILD_DIR} 
cd ${BUILD_DIR}
cmake -DPython_EXECUTABLE=${PYTHON} -DQt5_DIR=${Qt5_DIR} -DVISUS_GUI=${VISUS_GUI} -DVISUS_MODVISUS=${VISUS_MODVISUS} -DVISUS_SLAM=${VISUS_SLAM} ../
make -j 
make install

if [[ "1" == "1" ]]; then
	pushd Release/OpenVisus
	ConfigureAndTestCPython 
	DistribToPip
	popd
fi

if [[ "${VISUS_GUI}" == "1" ]]; then
	CreateNonGuiVersion
	pushd Release.nogui/OpenVisus 
	ConfigureAndTestCPython 
	DistribToPip 
	popd
fi

# /////////////////////////////////////////////////////////////////////////
# *** conda ***

# avoid conflicts with pip packages installed using --user
export PYTHONNOUSERSITE=True 

InstallConda 
ActivateConda

PYTHON=`which python`

# # fix for bdist_conda problem
#cp -n \
#	${CONDA_PREFIX}/lib/python${PYTHON_VERSION}/distutils/command/bdist_conda.py \
#	${CONDA_PREFIX}/lib/python${PYTHON_VERSION}/site-packages/setuptools/_distutils/command/bdist_conda.py


if [[ "1" == "1" ]]; then
	pushd Release/OpenVisus 
	ConfigureAndTestConda 
	DistribToConda 
	popd
fi

if [[ "${VISUS_GUI}" == "1" ]]; then
	pushd Release.nogui/OpenVisus
	ConfigureAndTestConda
	DistribToConda
	popd
fi



