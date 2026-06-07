-- 0006_queue_public.sql
-- Installation queue (regular / privileged) and public phones / payphones.

CREATE TABLE installation_queue (
    id                    BIGSERIAL PRIMARY KEY,
    applicant_last_name   TEXT NOT NULL,
    applicant_first_name  TEXT NOT NULL,
    applicant_middle_name TEXT,
    queue_type            queue_type NOT NULL DEFAULT 'regular',
    address_id            BIGINT NOT NULL REFERENCES address(id) ON DELETE RESTRICT,
    desired_pbx_id        BIGINT REFERENCES pbx(id) ON DELETE SET NULL,
    requested_at          DATE NOT NULL DEFAULT CURRENT_DATE,
    status                queue_status NOT NULL DEFAULT 'waiting',
    assigned_number_id    BIGINT REFERENCES phone_number(id) ON DELETE SET NULL,
    note                  TEXT
);
CREATE INDEX ix_queue_type ON installation_queue (queue_type);
CREATE INDEX ix_queue_status ON installation_queue (status);
CREATE INDEX ix_queue_requested ON installation_queue (requested_at);

-- Общественные телефоны и таксофоны по адресам.
CREATE TABLE public_phone (
    id              BIGSERIAL PRIMARY KEY,
    kind            public_phone_kind NOT NULL,
    pbx_id          BIGINT NOT NULL REFERENCES pbx(id) ON DELETE RESTRICT,
    address_id      BIGINT NOT NULL REFERENCES address(id) ON DELETE RESTRICT,
    phone_number_id BIGINT REFERENCES phone_number(id) ON DELETE SET NULL,
    installed_at    DATE NOT NULL DEFAULT CURRENT_DATE,
    active          BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX ix_public_kind ON public_phone (kind);
CREATE INDEX ix_public_pbx ON public_phone (pbx_id);
CREATE INDEX ix_public_address ON public_phone (address_id);
