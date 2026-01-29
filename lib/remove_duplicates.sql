-- Remove duplicate Categories (keeping the one with the lowest ID)
DELETE FROM omtbl_categories
WHERE id IN (
    SELECT id
    FROM (
        SELECT id,
        ROW_NUMBER() OVER (PARTITION BY lower(trim(name)) ORDER BY id) AS rnum
        FROM omtbl_categories
    ) t
    WHERE t.rnum > 1
);

-- Remove duplicate Brands
DELETE FROM omtbl_brands
WHERE id IN (
    SELECT id
    FROM (
        SELECT id,
        ROW_NUMBER() OVER (PARTITION BY lower(trim(name)) ORDER BY id) AS rnum
        FROM omtbl_brands
    ) t
    WHERE t.rnum > 1
);

-- Remove duplicate Product Types
DELETE FROM omtbl_producttypes
WHERE id IN (
    SELECT id
    FROM (
        SELECT id,
        ROW_NUMBER() OVER (PARTITION BY lower(trim(name)) ORDER BY id) AS rnum
        FROM omtbl_producttypes
    ) t
    WHERE t.rnum > 1
);
