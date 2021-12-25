To run:

```
PYPI_PASSWORD=XXXX
ANACONDA_TOKEN=YYYY
PYTHON_VERSION=3.8
sudo docker run --rm --platform linux/arm64 \
  -v $PWD:/home/OpenVisus \
  -w /home/OpenVisus \
  -e PYTHON_VERSION=$PYTHON_VERSION \
  -e PYPI_PASSWORD=$PYPI_PASSWORD \
  -e ANACONDA_TOKEN=$ANACONDA_TOKEN  \
  nsdf/manylinux2014_aarch64:latest \
  bash scripts/build-arm64/run.sh
```