FROM apache/spark:3.5.2

USER root

# Install minimal utilities
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    python3-pip \
    jq \
 && rm -rf /var/lib/apt/lists/*

# Install Python libraries used for experimentation
RUN pip3 install --no-cache-dir \
    delta-spark==3.2.0 \
    pyiceberg

# Configure Spark packages and extensions automatically for pyspark
ENV PYSPARK_SUBMIT_ARGS="\
--packages io.delta:delta-spark_2.12:3.2.0,org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.2,org.apache.spark:spark-avro_2.12:3.5.2 \
--conf spark.sql.catalogImplementation=in-memory \
--conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension \
--conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog \
--conf spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog \
--conf spark.sql.catalog.local.type=hadoop \
--conf spark.sql.catalog.local.warehouse=/workspace/lake \
pyspark-shell"

ENV PYSPARK_PYTHON=python3

WORKDIR /workspace

RUN mkdir -p /workspace/lake
