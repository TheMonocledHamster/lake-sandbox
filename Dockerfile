FROM apache/spark:4.0.2

ARG SPARK_VERSION=4.0.2
ARG DELTA_VERSION=4.0.0
ARG ICEBERG_VERSION=1.6.1
ARG SCALA_VERSION=2.13

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-pip curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir \
    jupyterlab \
    ipykernel \
    py4j

ENV PYTHONPATH=/opt/spark/python
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

RUN mkdir -p /home/spark \
    && chown -R spark:spark /home/spark

ENV HOME=/home/spark

RUN curl -L https://repo1.maven.org/maven2/io/delta/delta-spark_${SCALA_VERSION}/${DELTA_VERSION}/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar \
    -o /opt/spark/jars/delta-spark.jar \
    && curl -L https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-4.0_${SCALA_VERSION}/${ICEBERG_VERSION}/iceberg-spark-runtime-4.0_${SCALA_VERSION}-${ICEBERG_VERSION}.jar \
    -o /opt/spark/jars/iceberg-runtime.jar \
    && curl -L https://repo1.maven.org/maven2/org/apache/spark/spark-avro_${SCALA_VERSION}/${SPARK_VERSION}/spark-avro_${SCALA_VERSION}-${SPARK_VERSION}.jar \
    -o /opt/spark/jars/spark-avro.jar

COPY spark-defaults.conf /opt/spark/conf/spark-defaults.conf

RUN mkdir -p /workspace /lake \
    && chown -R spark:spark /workspace /lake

USER spark

WORKDIR /workspace

EXPOSE 8888 4040

CMD ["jupyter","lab","--ip=0.0.0.0","--port=8888","--no-browser","--IdentityProvider.token=", "--ServerApp.disable_check_xsrf=True"]
