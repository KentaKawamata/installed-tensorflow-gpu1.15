FROM nvidia/cuda:10.0-devel-ubuntu16.04

ENV HOME /root

RUN apt-get update && apt-get install -y --no-install-recommends \
        pkg-config \
        libxau-dev \
        libxdmcp-dev \
        libxcb1-dev \
        libxext-dev \
        libx11-dev  \
        x11-apps \
        ca-certificates \
        build-essential \
        cmake \
        git \
        wget \
        unzip \
        curl \
        vim && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/*

##################################################################################################################
RUN echo 'export PATH=/usr/local/cuda-10.0/bin${PATH:+:${PATH}}' >> ~/.bashrc && \
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-10.0/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc
##################################################################################################################
    
# cuDNN version must match the one used by TensorRT.
# TRT 4.0 is compiled with cuDNN 7.6.4.38-1+cuda10.0
#########################################################################
RUN apt-get update && apt-get -y --no-install-recommends install \
        ca-certificates \
        build-essential \
        libcudnn7=7.6.4.38-1+cuda10.0 \
        libcudnn7-dev=7.6.4.38-1+cuda10.0 \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*
########################################################################

# Install VSCode
#####################################################################################################
RUN apt-get update -y && \
    apt-get install -y apt-transport-https libasound-dev && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
RUN install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
RUN sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
RUN apt-get update -y && \
    apt-get install -y code && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/*

RUN echo '#!/bin/bash' >> /start_code.sh && \
    echo ' ' >> /start_code.sh && \
    echo 'code --user-data-dir="~/.vscode-root"' >> /start_code.sh
RUN chmod 777 /start_code.sh
#####################################################################################################

# Install pyenv
# reference: https://qiita.com/pdv/items/1107bcdca7fa43de673d
#####################################################################################################
ENV PYENV_ROOT $HOME/.pyenv
ENV PATH $PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH
RUN apt-get update -y && \
    apt-get install -y build-essential \
    libffi-dev \
    libssl-dev \
    zlib1g-dev \
    liblzma-dev \
    libbz2-dev libreadline-dev libsqlite3-dev && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/pyenv/pyenv.git  $HOME/.pyenv
RUN chmod 777 $HOME/.pyenv -R
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> $HOME/.bashrc && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> $HOME/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> $HOME/.bashrc &&\
    eval "$(pyenv init -)"
#####################################################################################################


# Install Python 3.6.8
# Build using bash in Dockerfile: https://kantaro-cgi.com/blog/docker/dockerfile-build-by-bash.html
#####################################################################################################
RUN /bin/bash -c  ' source $HOME/.bashrc && \
                    export PYENV_ROOT="$HOME/.pyenv" && \
                    export PATH="$PYENV_ROOT/bin:$PATH" && \
                    eval "$(pyenv init -)" && \
                    pyenv install 3.6.8 && \
                    pyenv global 3.6.8'
#####################################################################################################

# Install pip and pip packages
#####################################################################################################
WORKDIR /
COPY ./requirements.txt /
ENV PYENV_ROOT $HOME/.pyenv
ENV PATH $PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH
RUN /bin/bash -c  ' source ~/.bashrc && \
                    apt-get update && \
                    export PYENV_ROOT="$HOME/.pyenv" && \
                    export PATH="$PYENV_ROOT/bin:$PATH" && \
                    eval "$(pyenv init -)" && \
                    apt-get install -y python-pip && \
                    pyenv exec pip install --upgrade pip && \
                    pyenv exec pip install --upgrade setuptools && \
                    pyenv exec pip install --no-cache-dir -r requirements.txt'
#####################################################################################################

# Install labelImg
#####################################################################################################
RUN apt-get install pyqt5-dev-tools -y && \
    git clone https://github.com/tzutalin/labelImg.git
WORKDIR /labelImg/
RUN /bin/bash -c  ' source ~/.bashrc && \
                    export PYENV_ROOT="$HOME/.pyenv" && \
                    export PATH="$PYENV_ROOT/bin:$PATH" && \
                    eval "$(pyenv init -)" && \
                    make qt5py3'
#####################################################################################################

# replace with other Ubuntu version if desired
# see: https://hub.docker.com/r/nvidia/opengl/
COPY --from=nvidia/opengl:1.0-glvnd-runtime-ubuntu16.04 \
  /usr/local/lib/x86_64-linux-gnu \
  /usr/local/lib/x86_64-linux-gnu

# replace with other Ubuntu version if desired
# see: https://hub.docker.com/r/nvidia/opengl/
COPY --from=nvidia/opengl:1.0-glvnd-runtime-ubuntu16.04 \
  /usr/local/share/glvnd/egl_vendor.d/10_nvidia.json \
  /usr/local/share/glvnd/egl_vendor.d/10_nvidia.json

RUN echo '/usr/local/lib/x86_64-linux-gnu' >> /etc/ld.so.conf.d/glvnd.conf && \
    ldconfig && \
    echo '/usr/local/$LIB/libGL.so.1' >> /etc/ld.so.preload && \
    echo '/usr/local/$LIB/libEGL.so.1' >> /etc/ld.so.preload

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES \
    ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES all


LABEL com.nvidia.volumes.needed="nvidia_driver"
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda-10.0/bin:/usr/local/cuda/bin:/usr/local/bin:/usr/local/sbin:/user/bin:/sbin:/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda-10.0/lib64:/usr/local/cuda-10.0/lib:/usr/local/cuda/lib:/usr/local/cuda/lib64:${LD_LIBRARY_PATH}


# Set up X window
ENV DISPLAY :0
ENV TERM=xterm
# Some QT-Apps don't not show controls without this
ENV QT_X11_NO_MITSHM 1

WORKDIR /
CMD ["/bin/bash"]
# USER original_user
