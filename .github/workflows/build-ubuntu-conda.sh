#!/bin/bash

set -e
set -x

uname -m

ENV_NAME=my-python

 # in case you want to install conda use this
 function install_conda(){
   pushd $HOME
   curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-4.11.0-0-Linux-$(uname -m).sh -o install.sh 
   bash install.sh -b 
   rm -f install.sh
   popd
 }


GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || true)


# configure conda
conda_packages=(python=${PYTHON_VERSION} numpy anaconda-client conda conda-build wheel gcc_linux-64 gxx_linux-64 make cmake swig)
if [[ "${VISUS_GUI}" == "1" ]]; then 
  conda_packages+=(pyqt)

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y libglu1-mesa-dev freeglut3-dev mesa-common-dev libgl1-mesa-dev
fi

conda create --name $ENV_NAME  -y -c conda-forge ${conda_packages[@]}
source /opt/conda/etc/profile.d/conda.sh
conda activate $ENV_NAME
conda config --set always_yes yes --set changeps1 no --set anaconda_upload no

# I know if this sounds crazy, but if I don't do the following, conda/pyqt5/VisusGUi cannot find GL/gl.h since it refuses to use /usr/include
# see https://gitlab.kitware.com/cmake/cmake/-/issues/17966
if [[ "${VISUS_GUI}" == "1" ]]; then 
  ln -s /usr/include/GL /opt/conda/envs/$ENV_NAME/include/GL
  ln -s /usr/lib/x86_64-linux-gnu/libGL.so        /opt/conda/envs/$ENV_NAME/lib/libGL.so
  ln -s /usr/lib/x86_64-linux-gnu/libGL.so.1      /opt/conda/envs/$ENV_NAME/lib/libGL.so.1 
  ln -s /usr/lib/x86_64-linux-gnu/libGL.so.1.7.0  /opt/conda/envs/$ENV_NAME/lib/libGL.so.1.7.0
fi

# compile openvisus
mkdir -p build
cd build

cmake \
  -DCMAKE_PREFIX_PATH=${CONDA_PREFIX} \
  -DCMAKE_INSTALL_PREFIX=${CONDA_PREFIX} \
  -DPython_EXECUTABLE=`which python` \
  -DVISUS_MODVISUS=0 \
  -DVISUS_GUI=${VISUS_GUI} \
  -DVISUS_SLAM=${VISUS_GUI} \
  -DQt5_DIR="${CONDA_PREFIX}/${Qt5_DIR}" \
   ../
   
make -j
make install

# configure and test
conda develop ${PWD}/Release
python -m OpenVisus configure || python -m OpenVisus configure
python -m OpenVisus test  
python -m OpenVisus test-gui
conda develop ${PWD}/Release --uninstall

# upload conda package
if [[ "${GIT_TAG}" != ""  ]] ; then
  pushd Release/OpenVisus
  cp --no-clobber $CONDA_PREFIX/lib/python${PYTHON_VERSION}/distutils/command/bdist_conda* $CONDA_PREFIX/lib/python${PYTHON_VERSION}/site-packages/setuptools/_distutils/command/ # fix for bdist_not found
  python setup.py -q bdist_conda 1>/dev/null
  __filename__=`find ${CONDA_PREFIX} -iname "openvisus*.tar.bz2"  | head -n 1`
  ${HOME}/anaconda3/bin/anaconda --verbose --show-traceback -t ${ANACONDA_TOKEN} upload "${__filename__}"
  popd
fi