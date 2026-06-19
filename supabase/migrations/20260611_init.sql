-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Branches Table
create table if not exists public.branches (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    address text,
    phone text,
    gstin text,
    created_at timestamptz default now()
);

-- 2. Profiles Table (linked to auth.users)
create table if not exists public.profiles (
    id uuid primary key references auth.users on delete cascade,
    username text not null unique,
    name text not null,
    role text not null check (role in ('admin', 'staff')),
    branch_id uuid references public.branches on delete set null,
    created_at timestamptz default now()
);

-- 3. Customers Table
create table if not exists public.customers (
    id uuid primary key default gen_random_uuid(),
    branch_id uuid not null references public.branches on delete cascade,
    name text not null,
    phone text not null,
    email text,
    address text,
    created_at timestamptz default now(),
    created_by uuid references public.profiles on delete set null,
    updated_at timestamptz default now(),
    updated_by uuid references public.profiles on delete set null,
    unique(branch_id, phone)
);

-- 4. Products Table
create table if not exists public.products (
    id uuid primary key default gen_random_uuid(),
    branch_id uuid not null references public.branches on delete cascade,
    name text not null,
    brand text,
    category text,
    sku text not null,
    selling_price numeric(12,2) not null, -- Inclusive of GST
    gst_rate numeric(5,2) not null default 0,
    stock integer not null default 0,
    created_at timestamptz default now(),
    created_by uuid references public.profiles on delete set null,
    updated_at timestamptz default now(),
    updated_by uuid references public.profiles on delete set null,
    unique(branch_id, sku)
);

-- 5. Bills Table
create table if not exists public.bills (
    id uuid primary key default gen_random_uuid(),
    bill_number text not null,
    branch_id uuid not null references public.branches on delete cascade,
    user_id uuid not null references public.profiles on delete set null,
    customer_id uuid references public.customers on delete set null,
    customer_name text not null,
    customer_phone text not null,
    items jsonb not null, -- Array of items
    sub_total numeric(12,2) not null,
    gst_amount numeric(12,2) not null,
    total numeric(12,2) not null,
    payment_status text not null check (payment_status in ('paid', 'unpaid')),
    created_at timestamptz default now(),
    created_by uuid references public.profiles on delete set null,
    updated_at timestamptz default now(),
    updated_by uuid references public.profiles on delete set null,
    unique(branch_id, bill_number)
);

-- Disable Row Level Security for simplicity in development and internal use
alter table public.branches disable row level security;
alter table public.profiles disable row level security;
alter table public.customers disable row level security;
alter table public.products disable row level security;
alter table public.bills disable row level security;

-- Trigger to update updated_at timestamp
create or replace function public.update_updated_at_column()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger update_customers_updated_at
    before update on public.customers
    for each row execute procedure public.update_updated_at_column();

create trigger update_products_updated_at
    before update on public.products
    for each row execute procedure public.update_updated_at_column();

create trigger update_bills_updated_at
    before update on public.bills
    for each row execute procedure public.update_updated_at_column();

-- Trigger to sync auth.users to public.profiles
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, username, name, role, branch_id)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'username', new.email),
        coalesce(new.raw_user_meta_data->>'name', 'Staff Member'),
        coalesce(new.raw_user_meta_data->>'role', 'staff'),
        case 
            when new.raw_user_meta_data->>'branch_id' is not null and new.raw_user_meta_data->>'branch_id' != '' 
            then (new.raw_user_meta_data->>'branch_id')::uuid 
            else null 
        end
    );
    return new;
end;
$$ language plpgsql security definer;

-- Remove the trigger if it already exists
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();
