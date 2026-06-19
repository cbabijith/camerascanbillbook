-- Create invoices storage bucket if it does not exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('invoices', 'invoices', true, 5242880, '{"application/pdf"}')
ON CONFLICT (id) DO NOTHING;

-- Set up policies for public access to the invoices bucket
DROP POLICY IF EXISTS "Allow Public Access to Invoices" ON storage.objects;
CREATE POLICY "Allow Public Access to Invoices"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'invoices');

DROP POLICY IF EXISTS "Allow Public Upload of Invoices" ON storage.objects;
CREATE POLICY "Allow Public Upload of Invoices"
ON storage.objects FOR INSERT
TO public
WITH CHECK (bucket_id = 'invoices');
