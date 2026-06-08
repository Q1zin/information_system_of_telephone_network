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

UPDATE permission
   SET description = perm_action_ru(split_part(code, ':', 2))
                     || ' — ' ||
                     perm_entity_ru(split_part(code, ':', 1))
 WHERE code LIKE '%:%'
   AND code NOT IN ('analytics:read', 'raw_query:run', 'rbac:manage');

UPDATE permission SET description = 'Аналитические запросы (по варианту)'        WHERE code = 'analytics:read';
UPDATE permission SET description = 'Выполнение произвольных SQL-запросов (SELECT)' WHERE code = 'raw_query:run';
UPDATE permission SET description = 'Управление ролями и правами'                 WHERE code = 'rbac:manage';

UPDATE role SET description = 'Полный доступ ко всему'                       WHERE name = 'superadmin';
UPDATE role SET description = 'Управление данными сети, аналитика и SQL-запросы' WHERE name = 'operator';
UPDATE role SET description = 'Доступ только для чтения'                     WHERE name = 'viewer';
