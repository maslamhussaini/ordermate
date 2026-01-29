-- Enable RLS on the table if not already enabled
ALTER TABLE omtbl_businesspartners ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows all operations for authenticated users
-- Drop existing implementation-specific policies if needed to avoid conflicts or just create a blanket one
DROP POLICY IF EXISTS "Allow all for authenticated" ON omtbl_businesspartners;

CREATE POLICY "Allow all for authenticated"
ON omtbl_businesspartners
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Also ensure states table has policies
ALTER TABLE omtbl_states ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read for authenticated" ON omtbl_states;
CREATE POLICY "Allow read for authenticated"
ON omtbl_states FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow insert for authenticated" ON omtbl_states;
CREATE POLICY "Allow insert for authenticated"
ON omtbl_states FOR INSERT TO authenticated WITH CHECK (true);
