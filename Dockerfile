FROM apache/spark:3.5.2

USER root

RUN apt-get update && \
    apt-get install -y python3-pip jq curl && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install \
    pyspark==3.5.2 \
    delta-spark==3.2.0 \
    pyiceberg

ENV PYSPARK_PYTHON=python3

WORKDIR /workspace

RUN mkdir -p /workspace/lake
