CREATE TABLE customer (
    id            BIGSERIAL PRIMARY KEY,
    login         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    last_name     TEXT NOT NULL,
    first_name    TEXT NOT NULL,
    middle_name   TEXT,
    gender        gender NOT NULL,
    birth_date    DATE NOT NULL
        CHECK (birth_date > DATE '1900-01-01' AND birth_date < CURRENT_DATE),
    category      subscriber_category NOT NULL DEFAULT 'regular',
    privilege     privilege_kind,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_customer_privilege CHECK (
        (category = 'privileged' AND privilege IS NOT NULL) OR
        (category = 'regular'    AND privilege IS NULL)
    )
);

ALTER TABLE subscriber
    ADD COLUMN customer_id BIGINT REFERENCES customer(id) ON DELETE SET NULL;
CREATE INDEX ix_subscriber_customer ON subscriber (customer_id);

ALTER TABLE installation_queue
    ADD COLUMN customer_id BIGINT REFERENCES customer(id) ON DELETE SET NULL;
CREATE INDEX ix_queue_customer ON installation_queue (customer_id);
