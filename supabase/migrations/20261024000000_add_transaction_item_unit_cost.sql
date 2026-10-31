alter table public.transaction_items
add column if not exists unit_cost bigint;
