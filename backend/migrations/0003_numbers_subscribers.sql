CREATE TABLE phone_number (
    id         BIGSERIAL PRIMARY KEY,
    number     TEXT NOT NULL UNIQUE,
    pbx_id     BIGINT NOT NULL REFERENCES pbx(id) ON DELETE RESTRICT,
    line_type  line_type NOT NULL DEFAULT 'main',
    intercity  intercity_status NOT NULL DEFAULT 'none',
    status     number_status NOT NULL DEFAULT 'free',
    address_id BIGINT REFERENCES address(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_phone_pbx ON phone_number (pbx_id);
CREATE INDEX ix_phone_status ON phone_number (status);
CREATE INDEX ix_phone_address ON phone_number (address_id);
CREATE INDEX ix_phone_linetype ON phone_number (line_type);
CREATE INDEX ix_phone_intercity ON phone_number (intercity);

CREATE TABLE subscriber (
    id              BIGSERIAL PRIMARY KEY,
    last_name       TEXT NOT NULL,
    first_name      TEXT NOT NULL,
    middle_name     TEXT,
    gender          gender NOT NULL,
    birth_date      DATE NOT NULL
        CHECK (birth_date > DATE '1900-01-01' AND birth_date < CURRENT_DATE),
    category        subscriber_category NOT NULL DEFAULT 'regular',
    privilege       privilege_kind,
    status          subscriber_status NOT NULL DEFAULT 'active',
    phone_number_id BIGINT NOT NULL REFERENCES phone_number(id) ON DELETE RESTRICT,
    address_id      BIGINT NOT NULL REFERENCES address(id) ON DELETE RESTRICT,
    connected_at    DATE NOT NULL DEFAULT CURRENT_DATE,
    disconnected_at DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_privilege CHECK (
        (category = 'privileged' AND privilege IS NOT NULL) OR
        (category = 'regular'    AND privilege IS NULL)
    )
);
CREATE INDEX ix_sub_number ON subscriber (phone_number_id);
CREATE INDEX ix_sub_category ON subscriber (category);
CREATE INDEX ix_sub_status ON subscriber (status);
CREATE INDEX ix_sub_lastname ON subscriber (last_name);
CREATE INDEX ix_sub_address ON subscriber (address_id);
CREATE INDEX ix_sub_birth ON subscriber (birth_date);
