# Kafka Cluster Infrastructure

This repository contains the Docker Compose setup for the Kafka cluster used across the data streaming assignments: a single-node Kafka broker, Schema Registry, Kafka Connect (with all sink/source connectors), and ksqlDB.

This cluster is used by the [stationery-store](https://github.com/dts-org/stationery-store) application as the backing infrastructure for its Kafka producer.
The broker and Schema Registry addresses configured here (`localhost:9092` and `http://localhost:8085`) are the same ones used in that application to register Avro schemas and send review events.

## Services

### Kafka Broker

Single-node Kafka broker, running in combined `broker,controller` mode.

- Exposed on `localhost:9092` (host) / `kafka-broker:29092` (internal Docker network)
- `KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR`, `KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR`, and `KAFKA_TRANSACTION_STATE_LOG_MIN_ISR` are all set to `1`, since this is a single-broker cluster (there are no other brokers to replicate to).

### Schema Registry

Stores and serves the Avro schemas used to serialize/deserialize messages on the topics below.

- Exposed on `localhost:8085` (mapped to container port `8081`)
- Connects to the broker via `kafka-broker:29092`

### Kafka Connect

On startup, Kafka Connect only **installs the connector plugins** via `confluent-hub`. Connectors are created afterward, manually, by sending REST requests (specified in `instConn.http`).

## Connectors

### Source connector (1)

| Connector name | Topic | Purpose |
|---|---|---|
| `postgres-debezium-connector` | `neondb.public.Product` | Debezium source connector that captures changes (CDC) from the `Product` table in the PostgreSQL (Neon) database and writes each change as an event to Kafka. |

### Sink connectors (3)

| Connector name | Topic | Purpose |
|---|---|---|
| `cassandra-sink-reviews-by-rating` | `reviews` | Reads review events (rating, product, user, title, description) and writes them into the `reviews_by_rating` table in the `ecommerce_reviews` Cassandra keyspace. This is the basic review tracking sink — every review event ends up here as-is. |
| `cassandra-sink-product-review-avg-windowed` | `REV_AVG_WIN` | Reads the results of a windowed average-rating aggregation (built with ksqlDB) and writes them into the `product_review_avg_windowed_pkpid` table in the `product_analytics` keyspace. This is the sink used for the real-time aggregation results (average rating per product over a time window). |
| `s3-bronze-sink` | `neondb.public.Product` | Reads the CDC events produced by the Debezium connector above and writes them as JSON into the `bronze` zone of the MinIO (S3-compatible) data lake, in the `datalake` bucket. |
### ksqlDB (server + CLI)

ksqlDB server and CLI for building streams/tables on top of the Kafka topics, including windowed aggregations.

- ksqlDB server exposed on `localhost:8088`
- Connected to the broker, Schema Registry, and Kafka Connect
- `ksqlDB-cli` is a standalone container kept alive (`sleep infinity`) so it can be entered with `docker exec` to run ksqlDB CLI commands

## Connectors

All connectors are created via REST calls to `http://localhost:8083/connectors` (see the included `.http` request file for the exact payloads used to create, check the status of, and delete each one).

| Connector name | Topic | Purpose |
|---|---|---|
| `cassandra-sink-reviews-by-rating` | `reviews` | Reads review events (rating, product, user, title, description) and writes them into the `reviews_by_rating` table in the `ecommerce_reviews` Cassandra keyspace. This is the basic review tracking sink — every review event ends up here as-is. |
| `cassandra-sink-product-review-avg-windowed` | `REV_AVG_WIN` | Reads the results of a windowed average-rating aggregation (built with ksqlDB) and writes them into the `product_review_avg_windowed_pkpid` table in the `product_analytics` keyspace. This is the sink used for the real-time aggregation results (average rating per product over a time window). |
| `postgres-debezium-connector` | `neondb.public.Product` | Debezium source connector that captures changes (CDC) from the `Product` table in the PostgreSQL (Neon) database and writes each change as an event to Kafka. |
| `s3-bronze-sink` | `neondb.public.Product` | Reads the CDC events produced by the Debezium connector above and writes them as JSON into the `bronze` zone of the MinIO (S3-compatible) data lake, in the `datalake` bucket. |

> The `cassandra-sink-product-review-avg-windowed` connector reads from a stream/table created with ksqlDB rather than a raw producer topic. That stream/table can be created using ksqlDB CLI commands.

## CDC Setup (PostgreSQL / Neon)

To enable Change Data Capture on the `Product` table in the Neon-hosted PostgreSQL database, please execute the SQL statements from [neon-debezium-setup.sql](https://github.com/dts-org/kafka-streaming-platform/blob/main/neon-debezium-setup.sql) in the Neon SQL Editor on the corresponding Neon database instance.

This grants the replication user read access, enables full row data on updates/deletes (`REPLICA IDENTITY FULL`), and creates the publication and replication slot that the Debezium connector (`postgres-debezium-connector`) uses to stream changes.

## Connector Requests File

The `instConn.http` file included in this repository contains the REST requests used to:

- create all four connectors listed above
- check the status of each connector
- list registered connectors and available connector plugins
- inspect and delete schema subjects/versions in the Schema Registry
- restart or delete connectors when needed

## Networks

- `cassandra-network` — external network shared with the Cassandra cluster setup
- `datalakeminio` — external network shared with the MinIO data lake setup

Both networks are expected to already exist (created by their respective setups) before starting this cluster.
