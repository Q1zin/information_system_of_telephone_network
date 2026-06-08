CREATE TABLE city (
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE,
    is_home    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_city_home ON city (is_home) WHERE is_home;

CREATE TABLE address (
    id           BIGSERIAL PRIMARY KEY,
    postal_index TEXT NOT NULL,
    district     TEXT NOT NULL,
    street       TEXT NOT NULL,
    house        TEXT NOT NULL,
    apartment    TEXT,
    CONSTRAINT uq_address UNIQUE (postal_index, district, street, house, apartment)
);
CREATE INDEX ix_address_district ON address (district);
CREATE INDEX ix_address_house ON address (district, street, house);

CREATE TABLE pbx (
    id               BIGSERIAL PRIMARY KEY,
    name             TEXT NOT NULL UNIQUE,
    code             TEXT NOT NULL UNIQUE,
    pbx_type         pbx_type NOT NULL,
    district         TEXT NOT NULL,
    address_id       BIGINT REFERENCES address(id) ON DELETE SET NULL,
    capacity_numbers INTEGER NOT NULL CHECK (capacity_numbers >= 0),
    total_channels   INTEGER NOT NULL CHECK (total_channels >= 0),
    free_channels    INTEGER NOT NULL CHECK (free_channels >= 0),
    has_free_cable   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_pbx_channels CHECK (free_channels <= total_channels)
);
CREATE INDEX ix_pbx_type ON pbx (pbx_type);
CREATE INDEX ix_pbx_district ON pbx (district);

CREATE TABLE pbx_city (
    pbx_id            BIGINT PRIMARY KEY REFERENCES pbx(id) ON DELETE CASCADE,
    intercity_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    region_code       TEXT
);

CREATE TABLE pbx_department (
    pbx_id          BIGINT PRIMARY KEY REFERENCES pbx(id) ON DELETE CASCADE,
    department_name TEXT NOT NULL,
    closed_network  BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE pbx_institution (
    pbx_id            BIGINT PRIMARY KEY REFERENCES pbx(id) ON DELETE CASCADE,
    institution_name  TEXT NOT NULL,
    parent_department TEXT,
    closed_network    BOOLEAN NOT NULL DEFAULT TRUE
);
