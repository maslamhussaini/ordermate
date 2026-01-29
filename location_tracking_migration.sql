-- Location Tracking Feature Migration
-- Create this table to store movement history every 5 minutes

CREATE TABLE IF NOT EXISTS omtbl_location_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    organization_id INTEGER REFERENCES omtbl_organizations(id),
    store_id INTEGER REFERENCES omtbl_stores(id),
    user_id UUID REFERENCES omtbl_businesspartners(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION
);

-- Register the form in App Forms
-- Assuming omtbl_app_forms exists for menu management
INSERT INTO omtbl_app_forms (module_name, form_name, display_template, is_active)
VALUES ('Admin', 'Location Tracker', 'location_tracker', true)
ON CONFLICT (form_name) DO NOTHING;

-- Grant Permission to Admin Role
DO $$
DECLARE
    admin_role_id INTEGER;
    form_id INTEGER;
BEGIN
    SELECT id INTO admin_role_id FROM omtbl_roles WHERE name = 'Admin';
    SELECT id INTO form_id FROM omtbl_app_forms WHERE form_name = 'Location Tracker';

    IF admin_role_id IS NOT NULL AND form_id IS NOT NULL THEN
        -- Add to omtbl_role_form_privileges
        INSERT INTO omtbl_role_form_privileges (role_id, form_id, can_view, can_add, can_edit, can_delete, can_read, can_print)
        VALUES (admin_role_id, form_id, true, true, true, true, true, true)
        ON CONFLICT (role_id, form_id) DO UPDATE
        SET can_view = true, can_add = true, can_edit = true, can_delete = true, can_read = true, can_print = true;
    END IF;
END $$;
