SHOW wal_level; -- logical

GRANT USAGE ON SCHEMA public TO replication_product;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO replication_product;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO replication_product;

ALTER TABLE "Product" REPLICA IDENTITY FULL;

CREATE PUBLICATION dbz_publication FOR TABLE "Product";

SELECT pg_create_logical_replication_slot('debezium', 'pgoutput');
