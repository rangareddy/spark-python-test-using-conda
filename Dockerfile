ARG ANACONDA_VERSION=${ANACONDA_VERSION:-"latest"}
FROM continuumio/anaconda3:${ANACONDA_VERSION}

ARG IMAGE_VERSION=${IMAGE_VERSION:-"1.0.0"}
ARG DEBIAN_FRONTEND=noninteractive
ARG JAVA_VERSION=${JAVA_VERSION:-"8"}

LABEL maintainer="Ranga Reddy <rangareddy.avula@gmail.com>"
LABEL org.opencontainers.image.authors="Ranga Reddy <rangareddy.avula@gmail.com>"
LABEL org.opencontainers.image.vendor="Ranga Reddy"
LABEL version="$IMAGE_VERSION"

ENV CONDA_HOME=${CONDA_HOME:-"/opt/conda"}
ENV JAVA_VERSION=${JAVA_VERSION:-"8"}
ENV DATA_DIR=${DATA_DIR:-"/opt/data"}

# http://blog.stuart.axelbrooke.com/python-3-on-spark-return-of-the-pythonhashseed
ENV PYTHONHASHSEED 0
ENV PYTHONIOENCODING UTF-8
ENV PIP_DISABLE_PIP_VERSION_CHECK 1
ENV PIP_ROOT_USER_ACTION=ignore

COPY --from=openjdk:8-jdk-slim /usr/local/openjdk-8 /usr/local/openjdk-8
ENV JAVA_HOME=/usr/local/openjdk-8
ENV PATH=$JAVA_HOME/bin:$PATH

RUN apt-get update && apt upgrade -y && \
    apt-get install -y --no-install-recommends \
        apt-utils tzdata vim less git wget curl gcc libpq-dev libgtk2.0-dev \
        net-tools build-essential software-properties-common cmake && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Update conda and install Java 8
RUN conda update --all -y && \
    conda install --prune -y -c conda-forge --freeze-installed nomkl && \
    conda clean -afy && \
    find $CONDA_HOME/ -follow -type f -name '*.a' -delete && \
    find $CONDA_HOME/ -follow -type f -name '*.pyc' -delete && \
    find $CONDA_HOME/ -follow -type f -name '*.js.map' -delete && \
    conda remove -y jupyter && \
    conda config --add channels conda-forge

#&& find /opt/conda/lib/python*/site-packages/bokeh/server/static -follow -type f -name '*.js' ! -name '*.min.js' -delete
# Optimize the Anaconda Docker image - https://jcristharif.com/conda-docker-tips.html

RUN conda --version && python -V && pip -V && java -version
COPY pyspark_examples /opt
COPY *.sh /opt

RUN chmod +x /opt/*.sh
ENTRYPOINT ["tail", "-f", "/dev/null"]
#ENTRYPOINT ["/opt/entrypoint.sh"]