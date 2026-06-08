CREATE TABLE tariff (
    id             BIGSERIAL PRIMARY KEY,
    line_type      line_type NOT NULL,
    with_intercity BOOLEAN NOT NULL,
    monthly_fee    NUMERIC(12,2) NOT NULL CHECK (monthly_fee >= 0),
    valid_from     DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT uq_tariff UNIQUE (line_type, with_intercity, valid_from)
);

CREATE TABLE billing_settings (
    id                 SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    privilege_discount NUMERIC(4,3) NOT NULL DEFAULT 0.500 CHECK (privilege_discount BETWEEN 0 AND 1),
    reconnection_fee   NUMERIC(12,2) NOT NULL DEFAULT 150.00 CHECK (reconnection_fee >= 0),
    penalty_daily_rate NUMERIC(6,5) NOT NULL DEFAULT 0.00100 CHECK (penalty_daily_rate >= 0),
    payment_due_day    SMALLINT NOT NULL DEFAULT 20 CHECK (payment_due_day BETWEEN 1 AND 28),
    notice_grace_days  SMALLINT NOT NULL DEFAULT 2 CHECK (notice_grace_days >= 0)
);

CREATE TABLE invoice (
    id            BIGSERIAL PRIMARY KEY,
    subscriber_id BIGINT NOT NULL REFERENCES subscriber(id) ON DELETE CASCADE,
    kind          invoice_kind NOT NULL,
    period_year   SMALLINT NOT NULL CHECK (period_year BETWEEN 1990 AND 2100),
    period_month  SMALLINT NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    amount        NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    due_date      DATE NOT NULL,
    status        invoice_status NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_invoice_period UNIQUE (subscriber_id, kind, period_year, period_month)
);
CREATE INDEX ix_invoice_sub ON invoice (subscriber_id);
CREATE INDEX ix_invoice_status ON invoice (status);
CREATE INDEX ix_invoice_due ON invoice (due_date);
CREATE INDEX ix_invoice_kind ON invoice (kind);

CREATE TABLE payment (
    id            BIGSERIAL PRIMARY KEY,
    subscriber_id BIGINT NOT NULL REFERENCES subscriber(id) ON DELETE CASCADE,
    invoice_id    BIGINT REFERENCES invoice(id) ON DELETE SET NULL,
    amount        NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    paid_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_payment_sub ON payment (subscriber_id);
CREATE INDEX ix_payment_invoice ON payment (invoice_id);

CREATE TABLE penalty (
    id            BIGSERIAL PRIMARY KEY,
    subscriber_id BIGINT NOT NULL REFERENCES subscriber(id) ON DELETE CASCADE,
    invoice_id    BIGINT REFERENCES invoice(id) ON DELETE SET NULL,
    amount        NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    reason        TEXT,
    accrued_at    DATE NOT NULL DEFAULT CURRENT_DATE,
    paid          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX ix_penalty_sub ON penalty (subscriber_id);

CREATE TABLE notification (
    id            BIGSERIAL PRIMARY KEY,
    subscriber_id BIGINT NOT NULL REFERENCES subscriber(id) ON DELETE CASCADE,
    kind          notification_kind NOT NULL,
    sent_at       DATE NOT NULL DEFAULT CURRENT_DATE,
    deadline      DATE NOT NULL,
    resolved      BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_notice_deadline CHECK (deadline >= sent_at)
);
CREATE INDEX ix_notification_sub ON notification (subscriber_id);
CREATE INDEX ix_notification_kind ON notification (kind);
