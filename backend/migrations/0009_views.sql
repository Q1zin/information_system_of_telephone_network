CREATE OR REPLACE FUNCTION fn_subscriber_monthly_fee(p_subscriber_id BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_line_type     line_type;
    v_has_intercity BOOLEAN;
    v_category      subscriber_category;
    v_fee           NUMERIC(12,2);
    v_discount      NUMERIC(4,3);
BEGIN
    SELECT pn.line_type, (pn.intercity = 'open'), s.category
      INTO v_line_type, v_has_intercity, v_category
      FROM subscriber s
      JOIN phone_number pn ON pn.id = s.phone_number_id
     WHERE s.id = p_subscriber_id;

    SELECT monthly_fee INTO v_fee
      FROM tariff
     WHERE line_type = v_line_type AND with_intercity = v_has_intercity
     ORDER BY valid_from DESC
     LIMIT 1;

    IF v_fee IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_category = 'privileged' THEN
        SELECT privilege_discount INTO v_discount FROM billing_settings WHERE id = 1;
        v_fee := round(v_fee * (1 - COALESCE(v_discount, 0.5)), 2);
    END IF;

    RETURN v_fee;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE VIEW v_subscriber_full AS
SELECT s.id,
       s.last_name, s.first_name, s.middle_name,
       s.gender, s.birth_date,
       date_part('year', age(s.birth_date))::int AS age,
       s.category, s.privilege, s.status,
       s.connected_at, s.disconnected_at,
       pn.id   AS phone_number_id, pn.number, pn.line_type, pn.intercity,
       pn.status AS number_status,
       p.id    AS pbx_id, p.name AS pbx_name, p.pbx_type, p.district AS pbx_district,
       a.id    AS address_id, a.postal_index, a.district, a.street, a.house, a.apartment
FROM subscriber s
JOIN phone_number pn ON pn.id = s.phone_number_id
JOIN pbx p          ON p.id = pn.pbx_id
JOIN address a      ON a.id = s.address_id;

CREATE OR REPLACE VIEW v_subscriber_debt AS
SELECT s.id AS subscriber_id,
       COALESCE(sub.amt, 0)   AS subscription_debt,
       COALESCE(inter.amt, 0) AS intercity_debt,
       COALESCE(pen.amt, 0)   AS penalty_debt,
       COALESCE(sub.amt, 0) + COALESCE(inter.amt, 0) + COALESCE(pen.amt, 0) AS total_debt,
       LEAST(sub.oldest, inter.oldest) AS oldest_due_date
FROM subscriber s
LEFT JOIN (
    SELECT subscriber_id, sum(amount) AS amt, min(due_date) AS oldest
    FROM invoice
    WHERE kind = 'subscription' AND status IN ('pending', 'overdue')
    GROUP BY subscriber_id
) sub ON sub.subscriber_id = s.id
LEFT JOIN (
    SELECT subscriber_id, sum(amount) AS amt, min(due_date) AS oldest
    FROM invoice
    WHERE kind = 'intercity' AND status IN ('pending', 'overdue')
    GROUP BY subscriber_id
) inter ON inter.subscriber_id = s.id
LEFT JOIN (
    SELECT subscriber_id, sum(amount) AS amt
    FROM penalty WHERE NOT paid
    GROUP BY subscriber_id
) pen ON pen.subscriber_id = s.id;

CREATE OR REPLACE VIEW v_pbx_stats AS
SELECT p.id AS pbx_id, p.name, p.pbx_type, p.district, p.capacity_numbers,
       p.free_channels, p.has_free_cable,
       count(pn.id) FILTER (WHERE pn.status = 'free')   AS free_numbers,
       count(pn.id)                                     AS total_numbers,
       count(DISTINCT s.id)                             AS subscribers
FROM pbx p
LEFT JOIN phone_number pn ON pn.pbx_id = p.id
LEFT JOIN subscriber s    ON s.phone_number_id = pn.id
GROUP BY p.id;
