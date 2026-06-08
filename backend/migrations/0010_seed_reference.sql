-- 0010_seed_reference.sql
-- Reference data the application depends on: permissions catalog, system roles,
-- billing settings and tariffs. (Demo/business data lives in backend/seeds/.)

-- Russian labels for permission actions/entities, used to build descriptions.
CREATE OR REPLACE FUNCTION perm_action_ru(act TEXT) RETURNS text AS $$
    SELECT CASE act
        WHEN 'read'   THEN 'Просмотр'
        WHEN 'create' THEN 'Создание'
        WHEN 'update' THEN 'Изменение'
        WHEN 'delete' THEN 'Удаление'
        ELSE act
    END;
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION perm_entity_ru(ent TEXT) RETURNS text AS $$
    SELECT CASE ent
        WHEN 'pbx'          THEN 'АТС'
        WHEN 'subscriber'   THEN 'Абоненты'
        WHEN 'phone_number' THEN 'Номера'
        WHEN 'address'      THEN 'Адреса'
        WHEN 'city'         THEN 'Города'
        WHEN 'call'         THEN 'Звонки'
        WHEN 'tariff'       THEN 'Тарифы'
        WHEN 'invoice'      THEN 'Счета'
        WHEN 'payment'      THEN 'Платежи'
        WHEN 'penalty'      THEN 'Пени'
        WHEN 'notification' THEN 'Уведомления'
        WHEN 'queue'        THEN 'Очередь установки'
        WHEN 'public_phone' THEN 'Таксофоны'
        WHEN 'user'         THEN 'Пользователи'
        WHEN 'role'         THEN 'Роли'
        WHEN 'billing_settings' THEN 'Настройки биллинга'
        WHEN 'pbx_city'         THEN 'АТС: городские'
        WHEN 'pbx_department'   THEN 'АТС: ведомственные'
        WHEN 'pbx_institution'  THEN 'АТС: учрежденческие'
        ELSE replace(ent, '_', ' ')
    END;
$$ LANGUAGE sql IMMUTABLE;

-- Permission catalog: <entity>:<action> + a few special permissions.
-- Russian, human-readable descriptions ("<Действие> — <Сущность>").
DO $$
DECLARE
    ent  TEXT;
    act  TEXT;
    ents TEXT[] := ARRAY[
        'pbx','subscriber','phone_number','address','city','call',
        'tariff','invoice','payment','penalty','notification',
        'queue','public_phone','user','role'
    ];
    acts TEXT[] := ARRAY['read','create','update','delete'];
    act_ru TEXT;
    ent_ru TEXT;
BEGIN
    FOREACH ent IN ARRAY ents LOOP
        ent_ru := perm_entity_ru(ent);
        FOREACH act IN ARRAY acts LOOP
            act_ru := perm_action_ru(act);
            INSERT INTO permission(code, description)
            VALUES (ent || ':' || act, act_ru || ' — ' || ent_ru)
            ON CONFLICT (code) DO NOTHING;
        END LOOP;
    END LOOP;

    INSERT INTO permission(code, description) VALUES
        ('analytics:read', 'Аналитические запросы (по варианту)'),
        ('raw_query:run',  'Выполнение произвольных SQL-запросов (SELECT)'),
        ('rbac:manage',    'Управление ролями и правами')
    ON CONFLICT (code) DO NOTHING;
END $$;

-- System roles (cannot be deleted; superadmin can still create custom roles).
INSERT INTO role (name, description, is_system) VALUES
    ('superadmin', 'Полный доступ ко всему', TRUE),
    ('operator',   'Управление данными сети, аналитика и SQL-запросы', TRUE),
    ('viewer',     'Доступ только для чтения', TRUE)
ON CONFLICT (name) DO NOTHING;

-- superadmin: every permission.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM role r CROSS JOIN permission p
WHERE r.name = 'superadmin'
ON CONFLICT DO NOTHING;

-- viewer: all read permissions + analytics.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM role r JOIN permission p
  ON (p.code LIKE '%:read' OR p.code = 'analytics:read')
WHERE r.name = 'viewer'
ON CONFLICT DO NOTHING;

-- operator: read/create/update on domain entities + analytics + raw query,
-- but no user/role management.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM role r JOIN permission p
  ON (p.code LIKE '%:read' OR p.code LIKE '%:create' OR p.code LIKE '%:update'
      OR p.code IN ('analytics:read', 'raw_query:run'))
WHERE r.name = 'operator'
  AND p.code NOT LIKE 'user:%'
  AND p.code NOT LIKE 'role:%'
ON CONFLICT DO NOTHING;

-- Billing settings (single row) and default tariffs.
INSERT INTO billing_settings (id) VALUES (1) ON CONFLICT DO NOTHING;

INSERT INTO tariff (line_type, with_intercity, monthly_fee) VALUES
    ('main',     FALSE, 200.00),
    ('main',     TRUE,  350.00),
    ('parallel', FALSE, 150.00),
    ('parallel', TRUE,  300.00),
    ('paired',   FALSE, 120.00),
    ('paired',   TRUE,  270.00)
ON CONFLICT DO NOTHING;
