-- Create indexes for performance optimization
create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_profiles_branch_id on public.profiles(branch_id);
create index if not exists idx_customers_branch_id on public.customers(branch_id);
create index if not exists idx_products_branch_id on public.products(branch_id);
create index if not exists idx_bills_branch_id on public.bills(branch_id);
create index if not exists idx_bills_created_at on public.bills(created_at desc);
