-- Add discount column to bills table (flat discount, nullable, default 0)
alter table public.bills add column if not exists discount numeric(12,2) default 0;
