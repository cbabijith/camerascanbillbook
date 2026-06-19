-- Add MRP column to products table (optional, nullable)
alter table public.products add column if not exists mrp numeric(12,2);

-- Make gst_rate nullable and default 0 (kept for backward compatibility with existing bills)
alter table public.products alter column gst_rate set default 0;
alter table public.products alter column gst_rate drop not null;
