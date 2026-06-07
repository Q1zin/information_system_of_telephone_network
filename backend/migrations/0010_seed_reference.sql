-- 0010_seed_reference.sql
-- Reference data the application depends on: permissions catalog, system roles,
-- billing settings and tariffs. (Demo/business data lives in backend/seeds/.)

-- Permission catalog: <entity>:<action> + a few special permissions.
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
BEGIN
    FOREACH ent IN ARRAY ents LOOP
        FOREACH act IN ARRAY acts LOOP
            INSERT INTO permission(code, description)
            VALUES (ent || ':' || act, initcap(act) || ' ' || replace(ent, '_', ' '))
            ON CONFLICT (code) DO NOTHING;
        END LOOP;
    END LOOP;

    INSERT INTO permission(code, description) VALUES
        ('analytics:read', 'Run analytical (variant) queries'),
        ('raw_query:run',  'Execute user-provided raw SQL'),
        ('rbac:manage',    'Manage roles and permissions')
    ON CONFLICT (code) DO NOTHING;
END $$;

-- System roles (cannot be deleted; superadmin can still create custom roles).
INSERT INTO role (name, description, is_system) VALUES
    ('superadmin', 'Full access to everything', TRUE),
    ('operator',   'Manage telephone-network data, run analytics & raw queries', TRUE),
    ('viewer',     'Read-only access', TRUE)
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
