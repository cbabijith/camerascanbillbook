-- Add advance_amount column to bills table (nullable, for advance/partial payments)
alter table public.bills add column if not exists advance_amount numeric(12,2) default 0;

-- Update payment_status check constraint to include 'advance' and 'partial'
alter table public.bills drop constraint if exists bills_payment_status_check;
alter table public.bills add constraint bills_payment_status_check 
    check (payment_status in ('paid', 'unpaid', 'advance', 'partial'));
