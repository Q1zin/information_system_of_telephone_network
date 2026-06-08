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

CREATE TRIGGER pbx_city_subtype        BEFORE INSERT OR UPDATE ON pbx_city
    FOR EACH ROW EXECUTE FUNCTION trg_pbx_subtype_check();
CREATE TRIGGER pbx_department_subtype  BEFORE INSERT OR UPDATE ON pbx_department
    FOR EACH ROW EXECUTE FUNCTION trg_pbx_subtype_check();
CREATE TRIGGER pbx_institution_subtype BEFORE INSERT OR UPDATE ON pbx_institution
    FOR EACH ROW EXECUTE FUNCTION trg_pbx_subtype_check();

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

CREATE TRIGGER number_intercity_check BEFORE INSERT OR UPDATE ON phone_number
    FOR EACH ROW EXECUTE FUNCTION trg_number_intercity_check();

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

CREATE TRIGGER subscriber_count_check BEFORE INSERT OR UPDATE ON subscriber
    FOR EACH ROW EXECUTE FUNCTION trg_subscriber_count_check();

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

CREATE TRIGGER subscriber_same_house_check BEFORE INSERT OR UPDATE ON subscriber
    FOR EACH ROW EXECUTE FUNCTION trg_subscriber_same_house_check();

CREATE OR REPLACE FUNCTION sync_number_status(p_number_id BIGINT) RETURNS void AS $$
DECLARE
    cnt INTEGER;
BEGIN
    IF p_number_id IS NULL THEN
        RETURN;
    END IF;
    SELECT count(*) INTO cnt FROM subscriber WHERE phone_number_id = p_number_id;
    UPDATE phone_number
       SET status = CASE
            WHEN status = 'blocked' THEN 'blocked'::number_status
            WHEN cnt > 0            THEN 'active'::number_status
            ELSE 'free'::number_status
       END
     WHERE id = p_number_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_number_status_sync() RETURNS trigger AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        PERFORM sync_number_status(NEW.phone_number_id);
    END IF;
    IF TG_OP IN ('DELETE', 'UPDATE') THEN
        PERFORM sync_number_status(OLD.phone_number_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER number_status_sync AFTER INSERT OR UPDATE OR DELETE ON subscriber
    FOR EACH ROW EXECUTE FUNCTION trg_number_status_sync();
