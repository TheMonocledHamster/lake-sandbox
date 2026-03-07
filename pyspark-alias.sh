alias tps="pyspark \
--packages \
io.delta:delta-spark_2.12:3.2.0,\
org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.2 \
--conf spark.sql.catalogImplementation=in-memory \
--conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension \
--conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog \
--conf spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog \
--conf spark.sql.catalog.local.type=hadoop \
--conf spark.sql.catalog.local.warehouse=/workspace/lake"
