-- Payment collections table to track individual payments against bills
create table if not exists public.payment_collections (
    id uuid primary key default gen_random_uuid(),
    bill_id uuid not null references public.bills on delete cascade,
    amount numeric(12,2) not null,
    payment_type text not null check (payment_type in ('advance', 'partial', 'final')),
    payment_method text not null default 'cash' check (payment_method in ('upi', 'bank', 'cash', 'card')),
    collected_by uuid references public.profiles on delete set null,
    collected_at timestamptz default now()
);

-- Disable Row Level Security (RLS) as done for other tables in init
alter table public.payment_collections disable row level security;

-- Index for efficient lookups by bill_id
create index if not exists idx_payment_collections_bill_id on public.payment_collections(bill_id);
