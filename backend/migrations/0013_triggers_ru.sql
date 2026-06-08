-- 0013_triggers_ru.sql
-- Replaces trigger functions with Russian, human-readable error messages.
-- Idempotent (CREATE OR REPLACE only): safe to apply to an existing database
-- without recreating tables or triggers. On a fresh database these definitions
-- match 0008 and are simply re-applied.

-- ---------------------------------------------------------------------------
-- Human-readable Russian labels for enum values embedded in error messages.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pbx_type_ru(t pbx_type) RETURNS text AS $$
    SELECT CASE t
        WHEN 'city'          THEN 'городская'
        WHEN 'departmental'  THEN 'ведомственная'
        WHEN 'institutional' THEN 'учрежденческая'
    END;
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION line_type_ru(t line_type) RETURNS text AS $$
    SELECT CASE t
        WHEN 'main'     THEN 'основной'
        WHEN 'paired'   THEN 'спаренный'
        WHEN 'parallel' THEN 'параллельный'
    END;
$$ LANGUAGE sql IMMUTABLE;

-- ---------------------------------------------------------------------------
-- T1. PBX subtype must match pbx.pbx_type.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_pbx_subtype_check() RETURNS trigger AS $$
DECLARE
    actual_type   pbx_type;
    expected_type pbx_type;
BEGIN
    SELECT pbx_type INTO actual_type FROM pbx WHERE id = NEW.pbx_id;
    expected_type := CASE TG_TABLE_NAME
        WHEN 'pbx_city'        THEN 'city'::pbx_type
        WHEN 'pbx_department'  THEN 'departmental'::pbx_type
        WHEN 'pbx_institution' THEN 'institutional'::pbx_type
    END;
    IF actual_type IS DISTINCT FROM expected_type THEN
        RAISE EXCEPTION 'АТС № % имеет тип «%», для неё нельзя создать запись подтипа «%»',
            NEW.pbx_id, pbx_type_ru(actual_type), pbx_type_ru(expected_type);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- T2. Intercity access is only valid for city PBX numbers.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_number_intercity_check() RETURNS trigger AS $$
DECLARE
    t pbx_type;
BEGIN
    SELECT pbx_type INTO t FROM pbx WHERE id = NEW.pbx_id;
    IF t = 'city' THEN
        IF NEW.intercity = 'none' THEN
            RAISE EXCEPTION 'Для номера городской АТС % межгород должен быть открыт или закрыт, а не отсутствовать', NEW.number;
        END IF;
    ELSE
        IF NEW.intercity <> 'none' THEN
            RAISE EXCEPTION 'Номер % принадлежит замкнутой сети (АТС типа «%») и не может иметь межгородскую связь', NEW.number, pbx_type_ru(t);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- T3. Number occupancy by line type.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_subscriber_count_check() RETURNS trigger AS $$
DECLARE
    lt       line_type;
    cnt      INTEGER;
    max_subs INTEGER;
BEGIN
    SELECT line_type INTO lt FROM phone_number WHERE id = NEW.phone_number_id;
    SELECT count(*) INTO cnt FROM subscriber
        WHERE phone_number_id = NEW.phone_number_id AND id <> NEW.id;
    max_subs := CASE lt
        WHEN 'main'     THEN 1
        WHEN 'paired'   THEN 2
        WHEN 'parallel' THEN 2147483647
    END;
    IF cnt + 1 > max_subs THEN
        RAISE EXCEPTION 'К номеру № % (тип линии «%») можно подключить не более % абонент(ов)',
            NEW.phone_number_id, line_type_ru(lt), max_subs;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- T4. Co-subscribers of one number must live in the same house.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_subscriber_same_house_check() RETURNS trigger AS $$
DECLARE
    lt        line_type;
    my_addr   address%ROWTYPE;
    num_addr  address%ROWTYPE;
    other     RECORD;
BEGIN
    SELECT line_type INTO lt FROM phone_number WHERE id = NEW.phone_number_id;
    SELECT * INTO my_addr FROM address WHERE id = NEW.address_id;

    SELECT a.* INTO num_addr
        FROM phone_number p JOIN address a ON a.id = p.address_id
        WHERE p.id = NEW.phone_number_id;
    IF FOUND THEN
        IF (num_addr.postal_index, num_addr.district, num_addr.street, num_addr.house)
           IS DISTINCT FROM
           (my_addr.postal_index, my_addr.district, my_addr.street, my_addr.house) THEN
            RAISE EXCEPTION
                'Адрес абонента должен совпадать с домом, где установлен номер';
        END IF;
    END IF;

    IF lt IN ('parallel', 'paired') THEN
        FOR other IN
            SELECT a.postal_index, a.district, a.street, a.house
            FROM subscriber s JOIN address a ON a.id = s.address_id
            WHERE s.phone_number_id = NEW.phone_number_id AND s.id <> NEW.id
        LOOP
            IF (other.postal_index, other.district, other.street, other.house)
               IS DISTINCT FROM
               (my_addr.postal_index, my_addr.district, my_addr.street, my_addr.house) THEN
                RAISE EXCEPTION
                    'Параллельные и спаренные абоненты одного номера должны проживать в одном доме';
            END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
