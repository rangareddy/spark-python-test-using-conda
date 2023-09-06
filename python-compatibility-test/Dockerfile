ARG MINICONDA_VERSION=${MINICONDA_VERSION:-"latest"}
FROM continuumio/miniconda3:${MINICONDA_VERSION}

ARG IMAGE_VERSION=${IMAGE_VERSION:-"1.0.0"} \
    DEBIAN_FRONTEND=noninteractive \
    JAVA_VERSION=${JAVA_VERSION:-"8"}

LABEL maintainer="Ranga Reddy <rangareddy.avula@gmail.com>"
LABEL org.opencontainers.image.authors="Ranga Reddy <rangareddy.avula@gmail.com>"
LABEL org.opencontainers.image.vendor="Ranga Reddy"
LABEL version="$IMAGE_VERSION"

ENV CONDA_HOME=${CONDA_HOME:-"/opt/conda"} \
    JAVA_VERSION=${JAVA_VERSION:-"8"} \
    DATA_DIR=${DATA_DIR:-"/opt/data"}

# http://blog.stuart.axelbrooke.com/python-3-on-spark-return-of-the-pythonhashseed
ENV PYTHONHASHSEED=0 \
    PYTHONIOENCODING=UTF-8 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore

COPY --from=openjdk:8-jdk-slim /usr/local/openjdk-8 /usr/local/openjdk-8
ENV JAVA_HOME=/usr/local/openjdk-8
ENV PATH=$JAVA_HOME/bin:$PATH

RUN apt-get update --fix-missing && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        apt-utils tzdata vim less git wget curl gcc libpq-dev libgtk2.0-dev \
        net-tools build-essential software-properties-common cmake bash-completion && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN conda update --all -y && \
    conda install --prune -y -c conda-forge --freeze-installed nomkl && \
    conda clean -afy && \
    find $CONDA_HOME/ -follow -type f -name '*.a' -delete && \
    find $CONDA_HOME/ -follow -type f -name '*.pyc' -delete && \
    find $CONDA_HOME/ -follow -type f -name '*.js.map' -delete && \
    conda config --add channels conda-forge && \
    conda config --set ssl_verify no
# Optimize the Anaconda Docker image - https://jcristharif.com/conda-docker-tips.html

COPY python-compatibility-test/*.sh /opt
COPY python-compatibility-test/spark_component/*.sh /opt
COPY python-compatibility-test/spark_component/pyspark_examples /opt/pyspark_examples

RUN chmod +x /opt/*.sh && conda --version && python -V && pip -V && java -version

ENTRYPOINT ["tail", "-f", "/dev/null"]