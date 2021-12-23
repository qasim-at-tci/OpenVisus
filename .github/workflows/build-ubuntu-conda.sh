#!/bin/bash

set -e
set -x

uname -m

GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || true)

# configure conda
conda_packages=(python=${PYTHON_VERSION} numpy anaconda-client conda conda-build wheel gcc_linux-64 gxx_linux-64 make cmake swig)
if [[ "${VISUS_GUI}" == "1" ]]; then 
  conda_packages+=(pyqt libglu mesalib)
fi

mamba create --name my-python  -y -c conda-forge ${conda_packages[@]}
source /opt/conda/etc/profile.d/conda.sh
conda activate my-python
conda config --set always_yes yes --set changeps1 no --set anaconda_upload no

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
python -m OpenVisus configure
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