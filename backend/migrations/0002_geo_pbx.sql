-- 0002_geo_pbx.sql
-- Cities, addresses and PBX (АТС) with class-table inheritance for the three types.

-- Cities reachable via long-distance calls; exactly one row is the home city.
CREATE TABLE city (
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE,
    is_home    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- At most one home city.
CREATE UNIQUE INDEX uq_city_home ON city (is_home) WHERE is_home;

-- Address = a concrete flat/location (индекс, район, улица, дом, квартира).
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

-- Base PBX (АТС): attributes common to all three types.
CREATE TABLE pbx (
    id               BIGSERIAL PRIMARY KEY,
    name             TEXT NOT NULL UNIQUE,
    code             TEXT NOT NULL UNIQUE,             -- exchange code / number prefix
    pbx_type         pbx_type NOT NULL,
    district         TEXT NOT NULL,
    address_id       BIGINT REFERENCES address(id) ON DELETE SET NULL,
    capacity_numbers INTEGER NOT NULL CHECK (capacity_numbers >= 0),
    total_channels   INTEGER NOT NULL CHECK (total_channels >= 0),
    free_channels    INTEGER NOT NULL CHECK (free_channels >= 0),
    has_free_cable   BOOLEAN NOT NULL DEFAULT TRUE,    -- техническая возможность: наличие кабеля
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_pbx_channels CHECK (free_channels <= total_channels)
);
CREATE INDEX ix_pbx_type ON pbx (pbx_type);
CREATE INDEX ix_pbx_district ON pbx (district);

-- Subtype tables (class-table inheritance). One-to-one with pbx;
-- a trigger (0008) keeps pbx.pbx_type consistent with the subtype table.

-- Городская АТС: имеет выход на межгород.
CREATE TABLE pbx_city (
    pbx_id            BIGINT PRIMARY KEY REFERENCES pbx(id) ON DELETE CASCADE,
    intercity_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    region_code       TEXT
);

-- Ведомственная АТС: замкнутая внутренняя сеть.
CREATE TABLE pbx_department (
    pbx_id          BIGINT PRIMARY KEY REFERENCES pbx(id) ON DELETE CASCADE,
    department_name TEXT NOT NULL,
    closed_network  BOOLEAN NOT NULL DEFAULT TRUE
);

-- Учрежденческая АТС: замкнутая внутренняя сеть.
CREATE TABLE pbx_institution (
    pbx_id            BIGINT PRIMARY KEY REFERENCES pbx(id) ON DELETE CASCADE,
    institution_name  TEXT NOT NULL,
    parent_department TEXT,
    closed_network    BOOLEAN NOT NULL DEFAULT TRUE
);
