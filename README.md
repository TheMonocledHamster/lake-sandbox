# Delta Lake vs Apache Iceberg — Commit-by-Commit Walkthrough

## Human-designed, AI-documented walkthrough.

This walkthrough performs **equivalent operations on both Delta Lake and Apache Iceberg** and inspects the **actual metadata generated during execution**.

Operations performed:

1. Create table
2. Append data
3. Delete rows
4. Merge updates

All identifiers and metadata shown below come from the real experiment logs.

---

# Environment Setup

Start Spark with both table formats enabled.

```bash
pyspark \
--packages \
io.delta:delta-spark_2.12:3.2.0,\
org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.2 \
--conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension \
--conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog \
--conf spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog \
--conf spark.sql.catalog.local.type=hadoop \
--conf spark.sql.catalog.local.warehouse=/workspace/lake
```

Initialize a database for Iceberg:

```python
spark.sql("CREATE DATABASE IF NOT EXISTS local.db")
```

---

# 1. Create Tables

Create equivalent tables for both systems.

## Iceberg

```python
spark.sql("""
CREATE TABLE local.db.iceberg_table (
  id INT,
  val STRING
) USING iceberg
""")
```

## Delta

```python
spark.sql("""
CREATE TABLE delta.`/workspace/lake/delta_table` (
  id INT,
  val STRING
)
USING delta
""")
```

---

# Resulting Metadata

```
Delta
_delta_log/
 00000000000000000000.json

Iceberg
metadata/
 v1.metadata.json
```

---

# Delta Commit 0 — CREATE TABLE

The first Delta log file contains:

```
commitInfo
metaData
protocol
```

Important fields:

| Field                     | Meaning                             |
| ------------------------- | ----------------------------------- |
| commitInfo.operation      | CREATE TABLE                        |
| protocol                  | minimum reader/writer compatibility |
| metaData.schemaString     | full schema definition              |
| metaData.partitionColumns | partition layout                    |

Example details:

```
operation: CREATE TABLE
engineInfo: Apache-Spark/3.5.2 Delta-Lake/3.2.0
```

---

# Iceberg Metadata v1

Important fields:

| Field               | Meaning                      |
| ------------------- | ---------------------------- |
| format-version      | Iceberg table format version |
| table-uuid          | persistent table identifier  |
| schemas             | table schema definition      |
| partition-specs     | partition layout             |
| current-snapshot-id | -1 (no snapshots yet)        |

Key observation:

```
current-snapshot-id = -1
```

This indicates **the table exists but contains no data snapshot yet**.

---

# 2. Append Data

Insert identical rows into both tables.

## Delta

```python
spark.sql("""
INSERT INTO delta.`/workspace/lake/delta_table`
VALUES (1,'a'),(2,'b'),(3,'c')
""")
```

## Iceberg

```python
spark.sql("""
INSERT INTO local.db.iceberg_table
VALUES (1,'a'),(2,'b'),(3,'c')
""")
```

---

# Delta Commit 1 — Append

New file:

```
00000000000000000001.json
```

Contents include:

```
commitInfo
add
add
add
```

Three data files were written.

Example statistics:

```
numFiles: 3
numOutputRows: 3
```

Each `add` entry contains:

| Field      | Meaning                   |
| ---------- | ------------------------- |
| path       | parquet file written      |
| size       | file size                 |
| stats      | min/max column statistics |
| dataChange | indicates mutation        |

Example statistics entry:

```
numRecords: 1
minValues: { id: 1 }
maxValues: { id: 1 }
```

---

# Iceberg Metadata v2 — Append Snapshot

Metadata file created:

```
v2.metadata.json
```

Key fields:

```
current-snapshot-id = 5756694794303324069
```

Snapshot entry:

```
sequence-number: 1
snapshot-id: 5756694794303324069
operation: append
added-data-files: 3
added-records: 3
```

This snapshot references a manifest list:

```
snap-5756694794303324069-*.avro
```

Structure created:

```
snapshot
  └ manifest list
        └ manifest
              └ data files
```

---

# 3. Delete Rows

Delete identical rows from both tables.

## Delta

```python
spark.sql("""
DELETE FROM delta.`/workspace/lake/delta_table`
WHERE id = 1
""")
```

## Iceberg

```python
spark.sql("""
DELETE FROM local.db.iceberg_table
WHERE id = 1
""")
```

---

# Delta Commit 2 — Delete

New log file:

```
00000000000000000002.json
```

Contents:

```
commitInfo
remove
```

Important metrics:

```
numDeletedRows: 1
numRemovedFiles: 1
```

The removed file:

```
part-00000-01418838-151a-42b4-8079-f0a3ed9b9400.snappy.parquet
```

Important observation:

**No rewritten file was created** because the deleted row occupied its own file.

---

# Iceberg Metadata v3 — Delete Snapshot

New metadata file:

```
v3.metadata.json
```

New snapshot:

```
sequence-number: 2
snapshot-id: 2445279414961191614
parent-snapshot-id: 5756694794303324069
operation: delete
deleted-data-files: 1
deleted-records: 1
```

Snapshot chain now:

```
5756694794303324069  (append)
        ↓
2445279414961191614  (delete)
```

---

# 4. Merge Updates

Create update dataset.

```python
updates = spark.createDataFrame(
[(2,"bb"),(4,"d")],
["id","val"]
)

updates.createOrReplaceTempView("updates")
```

---

## Delta Merge

```python
spark.sql("""
MERGE INTO delta.`/workspace/lake/delta_table` t
USING updates s
ON t.id = s.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
""")
```

---

## Iceberg Merge

```python
spark.sql("""
MERGE INTO local.db.iceberg_table t
USING updates s
ON t.id = s.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
""")
```

---

# Delta Commit 3 — Merge

New log file:

```
00000000000000000003.json
```

Contents:

```
commitInfo
add
remove
```

Metrics:

```
numTargetRowsUpdated: 1
numTargetRowsInserted: 1
numTargetFilesAdded: 1
numTargetFilesRemoved: 1
```

Result:

```
old file removed
new file written with updated rows
```

---

# Iceberg Metadata v4 — Merge Snapshot

New metadata file:

```
v4.metadata.json
```

Snapshot entry:

```
sequence-number: 3
snapshot-id: 45552659945426009
parent-snapshot-id: 2445279414961191614
operation: overwrite
```

Metrics:

```
added-data-files: 1
deleted-data-files: 1
added-records: 2
deleted-records: 1
```

Final snapshot chain:

```
append
5756694794303324069
      ↓
delete
2445279414961191614
      ↓
merge
45552659945426009
```

---

# Final Metadata State

## Delta

```
_delta_log/
00000000000000000000.json
00000000000000000001.json
00000000000000000002.json
00000000000000000003.json
```

Delta reconstructs state as:

```
state = replay(log entries)
```

---

## Iceberg

```
metadata/
v1.metadata.json
v2.metadata.json
v3.metadata.json
v4.metadata.json
```

Iceberg reconstructs state as:

```
state = follow current-snapshot-id
```

---

# Core Architectural Difference

| Feature               | Delta Lake                | Apache Iceberg              |
| --------------------- | ------------------------- | --------------------------- |
| state reconstruction  | replay transaction log    | follow snapshot pointer     |
| metadata structure    | append-only JSON log      | metadata + manifest tree    |
| checkpointing         | periodic checkpoint files | not required                |
| commit representation | ordered log entries       | immutable snapshot metadata |

---

# Key Insight

Both systems use **copy-on-write file rewriting**, but encode table evolution differently.

Delta:

```
progress = ordered commit log
```

Iceberg:

```
progress = snapshot metadata tree
```

This affects:

* metadata scaling
* commit conflict detection
* query planning
* time-travel semantics

---

# References

Delta Protocol
https://github.com/delta-io/delta/blob/master/PROTOCOL.md

Iceberg Specification
https://iceberg.apache.org/spec/
