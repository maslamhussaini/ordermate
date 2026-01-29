-- Insert Brand
INSERT INTO omtbl_brands (brandtype, status, created_at)
VALUES ('My Brand', 1, NOW());

-- Insert Category
INSERT INTO omtbl_categories (category, status, created_at)
VALUES ('My Category', 1, NOW());

-- Insert Product Type
INSERT INTO omtbl_producttypes (producttype, status, created_at)
VALUES ('My Type', 1, NOW());

-- Insert Unit of Measure
INSERT INTO omtbl_units_of_measure (unit_name, unit_symbol, unit_type, is_decimal_allowed, organization_id, created_at)
VALUES ('Kilogram', 'kg', 'Weight', 1, 1, NOW());

-- Insert Unit Conversion
INSERT INTO omtbl_unit_conversions (from_unit_id, to_unit_id, conversion_factor, organization_id, created_at)
VALUES (1, 2, 1000, 1, NOW());
