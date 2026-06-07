-- 0012_customer_portal.sql
-- Self-service customer accounts (личный кабинет абонента).

CREATE TABLE customer (
    id            BIGSERIAL PRIMARY KEY,
    login         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,                 -- Argon2
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

-- Link subscribers and installation requests back to the customer account.
ALTER TABLE subscriber
    ADD COLUMN customer_id BIGINT REFERENCES customer(id) ON DELETE SET NULL;
CREATE INDEX ix_subscriber_customer ON subscriber (customer_id);

ALTER TABLE installation_queue
    ADD COLUMN customer_id BIGINT REFERENCES customer(id) ON DELETE SET NULL;
CREATE INDEX ix_queue_customer ON installation_queue (customer_id);
