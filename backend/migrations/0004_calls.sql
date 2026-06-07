-- 0004_calls.sql
-- Call detail records (CDR). Intercity calls are collected and analysed at the ГТС;
-- external/internal calls support analytics for closed-network PBXs.

CREATE TABLE call_record (
    id             BIGSERIAL PRIMARY KEY,
    from_number_id BIGINT NOT NULL REFERENCES phone_number(id) ON DELETE CASCADE,
    call_type      call_type NOT NULL,
    dest_city_id   BIGINT REFERENCES city(id) ON DELETE SET NULL,        -- for intercity
    dest_number_id BIGINT REFERENCES phone_number(id) ON DELETE SET NULL, -- for local/internal
    started_at     TIMESTAMPTZ NOT NULL,
    duration_sec   INTEGER NOT NULL CHECK (duration_sec >= 0),
    cost           NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    -- intercity calls must reference a destination city
    CONSTRAINT chk_intercity_city CHECK (
        call_type <> 'intercity' OR dest_city_id IS NOT NULL
    )
);
CREATE INDEX ix_call_from ON call_record (from_number_id);
CREATE INDEX ix_call_type ON call_record (call_type);
CREATE INDEX ix_call_started ON call_record (started_at);
CREATE INDEX ix_call_dest_city ON call_record (dest_city_id);
