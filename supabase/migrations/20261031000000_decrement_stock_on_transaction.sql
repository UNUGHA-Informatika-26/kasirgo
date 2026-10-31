create or replace function public.complete_transaction_with_stock(
  transaction_data jsonb
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  transaction_id text := transaction_data ->> 'id';
  transaction_user_id uuid := (transaction_data ->> 'user_id')::uuid;
  transaction_item jsonb;
  inserted_rows integer;
begin
  if auth.uid() is null or transaction_user_id <> auth.uid() then
    raise exception 'Transaksi tidak sesuai dengan pengguna yang aktif.';
  end if;

  insert into public.transactions (
    id,
    user_id,
    created_at,
    total_amount,
    payment_method,
    cash_received,
    change_amount
  )
  values (
    transaction_id,
    transaction_user_id,
    (transaction_data ->> 'created_at')::timestamptz,
    (transaction_data ->> 'total_amount')::bigint,
    transaction_data ->> 'payment_method',
    (transaction_data ->> 'cash_received')::bigint,
    (transaction_data ->> 'change_amount')::bigint
  )
  on conflict (id) do nothing;

  get diagnostics inserted_rows = row_count;
  if inserted_rows = 0 then
    return;
  end if;

  for transaction_item in
    select value
    from jsonb_array_elements(transaction_data -> 'transaction_items')
  loop
    if transaction_item ->> 'product_id' is null then
      raise exception 'ID produk tidak tersedia pada item transaksi.';
    end if;

    update public.products
    set
      stock = stock - (transaction_item ->> 'quantity')::integer,
      status = case
        when stock - (transaction_item ->> 'quantity')::integer > 0
          then 'tersedia'
        else 'habis'
      end
    where id = (transaction_item ->> 'product_id')::uuid
      and user_id = transaction_user_id;

    if not found then
      raise exception 'Produk transaksi tidak ditemukan.';
    end if;
  end loop;

  insert into public.transaction_items (
    transaction_id,
    product_name,
    quantity,
    unit_price,
    unit_cost,
    subtotal
  )
  select
    transaction_id,
    item ->> 'product_name',
    (item ->> 'quantity')::integer,
    (item ->> 'unit_price')::bigint,
    (item ->> 'unit_cost')::bigint,
    (item ->> 'subtotal')::bigint
  from jsonb_array_elements(transaction_data -> 'transaction_items') as items(item);
end;
$$;
