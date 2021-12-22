# IMAGE_NAME=visus/portable-linux-binaries_x86_64:latest
# sudo docker build --tag $IMAGE_NAME --progress=plain .
# sudo docker login 
# sudo docker push $IMAGE_NAME

FROM nsdf/manylinux2010_x86_64:latest

WORKDIR /tmp

COPY httpd24.sh .
RUN bash httpd24.sh

RUN yum -y install xz \
	libX11-devel libx11-xcb-devel libXrender-devel libXau-devel libXext-devel \
	mesa-libGL-devel mesa-libGLU-devel \
	fontconfig fontconfig-devel freetype freetype-devel

COPY qt512.sh .
RUN bash qt512.sh 




