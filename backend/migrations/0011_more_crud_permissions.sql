DO $$
DECLARE
    ent  TEXT;
    act  TEXT;
    ents TEXT[] := ARRAY['pbx_city', 'pbx_department', 'pbx_institution'];
    acts TEXT[] := ARRAY['read', 'create', 'update', 'delete'];
BEGIN
    FOREACH ent IN ARRAY ents LOOP
        FOREACH act IN ARRAY acts LOOP
            INSERT INTO permission(code, description)
            VALUES (ent || ':' || act, initcap(act) || ' ' || replace(ent, '_', ' '))
            ON CONFLICT (code) DO NOTHING;
        END LOOP;
    END LOOP;

    INSERT INTO permission(code, description) VALUES
        ('billing_settings:read',   'Read billing settings'),
        ('billing_settings:update', 'Update billing settings')
    ON CONFLICT (code) DO NOTHING;
END $$;

-- superadmin role: all new permissions
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON TRUE
WHERE r.name = 'superadmin'
  AND p.code ~ '^(pbx_city|pbx_department|pbx_institution|billing_settings):'
ON CONFLICT DO NOTHING;

-- viewer: read only
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.code LIKE '%:read'
WHERE r.name = 'viewer'
  AND p.code ~ '^(pbx_city|pbx_department|pbx_institution|billing_settings):'
ON CONFLICT DO NOTHING;

-- operator: read/create/update
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p
    ON (p.code LIKE '%:read' OR p.code LIKE '%:create' OR p.code LIKE '%:update')
WHERE r.name = 'operator'
  AND p.code ~ '^(pbx_city|pbx_department|pbx_institution|billing_settings):'
ON CONFLICT DO NOTHING;
