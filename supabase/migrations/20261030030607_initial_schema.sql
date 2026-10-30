
-- =========================================================
-- TRESNA - INITIAL DATABASE SCHEMA
-- Migration: initial_schema
-- Database: PostgreSQL / Supabase
-- =========================================================

-- 1. ENUMS
-- ---------------------------------------------------------

create type public.app_role as enum (
    'admin',
    'staff'
);

create type public.document_type as enum (
    'remision',
    'sale'
);

create type public.document_status as enum (
    'draft',
    'confirmed',
    'cancelled'
);

create type public.inventory_movement_type as enum (
    'entry',
    'dispatch',
    'adjustment_in',
    'adjustment_out',
    'customer_return',
    'supplier_return'
);


-- 2. USER PROFILES
-- ---------------------------------------------------------

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    full_name text,
    role public.app_role not null default 'staff',
    created_at timestamptz not null default now()
);


-- 3. COMPANY SETTINGS
-- ---------------------------------------------------------

create table public.company_settings (
    id smallint primary key default 1 check (id = 1),
    company_name text not null default 'Tresna',
    identification_number text,
    email text,
    phone text,
    address text,
    logo_path text,
    updated_at timestamptz not null default now()
);

insert into public.company_settings (id, company_name)
values (1, 'Tresna');


-- 4. PRODUCTS
-- ---------------------------------------------------------

create table public.products (
    id uuid primary key default gen_random_uuid(),
    reference text not null,
    description text not null,
    purchase_price numeric(14,2) not null default 0
        check (purchase_price >= 0),
    sale_price numeric(14,2) not null default 0
        check (sale_price >= 0),
    unit text not null default 'unidad',
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    check (length(btrim(reference)) > 0),
    check (length(btrim(description)) > 0)
);

create unique index products_reference_unique_ci
    on public.products (lower(reference));

create index products_active_idx
    on public.products (is_active);


-- 5. PRODUCT IMAGES
-- ---------------------------------------------------------

create table public.product_images (
    id uuid primary key default gen_random_uuid(),
    product_id uuid not null
        references public.products(id) on delete restrict,
    storage_path text not null,
    alt_text text,
    is_primary boolean not null default false,
    sort_order integer not null default 0,
    created_at timestamptz not null default now(),

    check (length(btrim(storage_path)) > 0)
);

create index product_images_product_idx
    on public.product_images (product_id);

create unique index product_images_one_primary_idx
    on public.product_images (product_id)
    where is_primary = true;


-- 6. CUSTOMERS
-- ---------------------------------------------------------

create table public.customers (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    identification_type text,
    identification_number text,
    phone text,
    email text,
    address text,
    notes text,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    check (length(btrim(name)) > 0),
    check (
        identification_number is null
        or length(btrim(identification_number)) > 0
    )
);

create unique index customers_identification_unique
    on public.customers (
        identification_type,
        identification_number
    )
    where identification_number is not null;

create index customers_name_idx
    on public.customers (lower(name));


-- 7. COMMERCIAL DOCUMENTS
-- ---------------------------------------------------------

create table public.documents (
    id uuid primary key default gen_random_uuid(),
    document_type public.document_type not null,
    status public.document_status not null default 'draft',
    document_number text unique,
    customer_id uuid not null
        references public.customers(id) on delete restrict,
    issue_date date not null default current_date,
    due_date date,
    currency char(3) not null default 'COP',
    notes text,
    created_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    confirmed_at timestamptz,
    cancelled_at timestamptz,

    check (due_date is null or due_date >= issue_date),
    check (
        document_number is null
        or length(btrim(document_number)) > 0
    )
);

create index documents_customer_date_idx
    on public.documents (customer_id, issue_date desc);

create index documents_type_status_idx
    on public.documents (document_type, status);


-- 8. DOCUMENT ITEMS
-- ---------------------------------------------------------

create table public.document_items (
    id uuid primary key default gen_random_uuid(),
    document_id uuid not null
        references public.documents(id) on delete cascade,
    product_id uuid not null
        references public.products(id) on delete restrict,

    reference_snapshot text not null,
    description_snapshot text not null,
    unit_snapshot text not null default 'unidad',

    quantity numeric(14,3) not null
        check (quantity > 0),

    unit_price numeric(14,2) not null
        check (unit_price >= 0),

    line_total numeric(16,2)
        generated always as (
            round(quantity * unit_price, 2)
        ) stored,

    created_at timestamptz not null default now()
);

create index document_items_document_idx
    on public.document_items (document_id);

create index document_items_product_idx
    on public.document_items (product_id);


-- 9. DOCUMENT RELATIONS
-- ---------------------------------------------------------

create table public.document_relations (
    id uuid primary key default gen_random_uuid(),

    source_document_id uuid not null
        references public.documents(id) on delete restrict,

    target_document_id uuid not null
        references public.documents(id) on delete restrict,

    relation_type text not null
        check (relation_type = 'sale_from_remision'),

    created_at timestamptz not null default now(),

    check (source_document_id <> target_document_id),

    unique (
        source_document_id,
        target_document_id,
        relation_type
    )
);


-- 10. DOCUMENT NUMBER COUNTERS
-- ---------------------------------------------------------

create table public.document_counters (
    document_type public.document_type primary key,
    prefix text not null,
    next_number bigint not null default 1
        check (next_number > 0),
    padding smallint not null default 6
        check (padding between 1 and 12)
);

insert into public.document_counters (
    document_type,
    prefix,
    next_number,
    padding
)
values
    ('remision', 'REM', 1, 6),
    ('sale', 'VEN', 1, 6);


-- 11. INVENTORY MOVEMENTS
-- ---------------------------------------------------------

create table public.inventory_movements (
    id uuid primary key default gen_random_uuid(),

    product_id uuid not null
        references public.products(id) on delete restrict,

    movement_type public.inventory_movement_type not null,

    -- Positive = stock entry.
    -- Negative = stock exit.
    quantity_delta numeric(14,3) not null
        check (quantity_delta <> 0),

    unit_cost numeric(14,2)
        check (unit_cost is null or unit_cost >= 0),

    source_document_item_id uuid unique
        references public.document_items(id) on delete restrict,

    reference text,
    notes text,

    occurred_at timestamptz not null default now(),
    created_by uuid references auth.users(id) on delete set null,

    check (
        (movement_type in (
            'entry',
            'adjustment_in',
            'customer_return'
        ) and quantity_delta > 0)
        or
        (movement_type in (
            'dispatch',
            'adjustment_out',
            'supplier_return'
        ) and quantity_delta < 0)
    )
);

create index inventory_movements_product_date_idx
    on public.inventory_movements (product_id, occurred_at desc);


-- 12. ACCOUNTS RECEIVABLE
-- ---------------------------------------------------------

create table public.receivables (
    id uuid primary key default gen_random_uuid(),

    sale_document_id uuid not null unique
        references public.documents(id) on delete restrict,

    customer_id uuid not null
        references public.customers(id) on delete restrict,

    due_date date,

    original_amount numeric(16,2) not null
        check (original_amount > 0),

    created_at timestamptz not null default now()
);

create index receivables_customer_idx
    on public.receivables (customer_id);


-- 13. PAYMENTS
-- ---------------------------------------------------------

create table public.payments (
    id uuid primary key default gen_random_uuid(),

    customer_id uuid not null
        references public.customers(id) on delete restrict,

    amount numeric(16,2) not null
        check (amount > 0),

    payment_date date not null default current_date,

    payment_method text not null default 'other'
        check (
            payment_method in (
                'cash',
                'bank_transfer',
                'card',
                'other'
            )
        ),

    reference text,
    notes text,

    created_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now()
);

create index payments_customer_date_idx
    on public.payments (customer_id, payment_date desc);


-- 14. PAYMENT ALLOCATIONS
-- ---------------------------------------------------------

create table public.payment_allocations (
    id uuid primary key default gen_random_uuid(),

    payment_id uuid not null
        references public.payments(id) on delete restrict,

    receivable_id uuid not null
        references public.receivables(id) on delete restrict,

    amount numeric(16,2) not null
        check (amount > 0),

    created_at timestamptz not null default now(),

    unique (payment_id, receivable_id)
);

create index payment_allocations_receivable_idx
    on public.payment_allocations (receivable_id);


-- 15. UPDATED_AT FUNCTION
-- ---------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

create trigger set_company_settings_updated_at
before update on public.company_settings
for each row execute function public.set_updated_at();

create trigger set_products_updated_at
before update on public.products
for each row execute function public.set_updated_at();

create trigger set_customers_updated_at
before update on public.customers
for each row execute function public.set_updated_at();

create trigger set_documents_updated_at
before update on public.documents
for each row execute function public.set_updated_at();


-- 16. AUTOMATIC USER PROFILE CREATION
-- ---------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, full_name)
    values (
        new.id,
        nullif(btrim(new.raw_user_meta_data ->> 'full_name'), '')
    )
    on conflict (id) do nothing;

    return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();


-- 17. ADMIN ROLE CHECK
-- ---------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.profiles p
        where p.id = (select auth.uid())
          and p.role = 'admin'::public.app_role
    );
$$;

revoke all on function public.is_admin() from public;

grant execute on function public.is_admin()
to authenticated, service_role;


-- 18. INVENTORY VIEW
-- ---------------------------------------------------------

create view public.product_stock
with (security_invoker = true)
as
select
    p.id as product_id,
    p.reference,
    p.description,
    coalesce(sum(im.quantity_delta), 0)::numeric(14,3)
        as current_stock
from public.products p
left join public.inventory_movements im
    on im.product_id = p.id
group by p.id, p.reference, p.description;


-- 19. DOCUMENT TOTALS VIEW
-- ---------------------------------------------------------

create view public.document_totals
with (security_invoker = true)
as
select
    d.id as document_id,
    coalesce(sum(di.line_total), 0)::numeric(16,2)
        as total
from public.documents d
left join public.document_items di
    on di.document_id = d.id
group by d.id;


-- 20. RECEIVABLE BALANCES VIEW
-- ---------------------------------------------------------

create view public.receivable_balances
with (security_invoker = true)
as
select
    r.id as receivable_id,
    r.sale_document_id,
    d.document_number,
    r.customer_id,
    c.name as customer_name,
    d.issue_date,
    r.due_date,
    r.original_amount,

    coalesce(sum(pa.amount), 0)::numeric(16,2)
        as paid_amount,

    (
        r.original_amount - coalesce(sum(pa.amount), 0)
    )::numeric(16,2) as balance,

    greatest(current_date - d.issue_date, 0)
        as days_since_issue,

    case
        when r.due_date is not null
         and current_date > r.due_date
         and r.original_amount - coalesce(sum(pa.amount), 0) > 0
        then current_date - r.due_date
        else 0
    end as days_overdue

from public.receivables r

join public.documents d
    on d.id = r.sale_document_id

join public.customers c
    on c.id = r.customer_id

left join public.payment_allocations pa
    on pa.receivable_id = r.id

group by
    r.id,
    d.document_number,
    r.customer_id,
    c.name,
    d.issue_date,
    r.due_date,
    r.original_amount;


-- 21. ENABLE ROW LEVEL SECURITY
-- ---------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.company_settings enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.customers enable row level security;
alter table public.documents enable row level security;
alter table public.document_items enable row level security;
alter table public.document_relations enable row level security;
alter table public.document_counters enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.receivables enable row level security;
alter table public.payments enable row level security;
alter table public.payment_allocations enable row level security;


-- 22. PROFILE POLICIES
-- ---------------------------------------------------------

create policy profiles_select_own_or_admin
on public.profiles
for select
to authenticated
using (
    id = (select auth.uid())
    or (select public.is_admin())
);

create policy profiles_admin_manage
on public.profiles
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 23. COMPANY SETTINGS POLICIES
-- ---------------------------------------------------------

create policy company_settings_read_authenticated
on public.company_settings
for select
to authenticated
using (true);

create policy company_settings_admin_manage
on public.company_settings
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 24. PRODUCT POLICIES
-- ---------------------------------------------------------

create policy products_read_authenticated
on public.products
for select
to authenticated
using (true);

create policy products_admin_manage
on public.products
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 25. PRODUCT IMAGE POLICIES
-- ---------------------------------------------------------

create policy product_images_read_authenticated
on public.product_images
for select
to authenticated
using (true);

create policy product_images_admin_manage
on public.product_images
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 26. CUSTOMER POLICIES
-- ---------------------------------------------------------

create policy customers_read_authenticated
on public.customers
for select
to authenticated
using (true);

create policy customers_admin_manage
on public.customers
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 27. DOCUMENT POLICIES
-- ---------------------------------------------------------

create policy documents_read_authenticated
on public.documents
for select
to authenticated
using (true);

create policy documents_admin_manage
on public.documents
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 28. DOCUMENT ITEM POLICIES
-- ---------------------------------------------------------

create policy document_items_read_authenticated
on public.document_items
for select
to authenticated
using (true);

create policy document_items_admin_manage
on public.document_items
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 29. DOCUMENT RELATION POLICIES
-- ---------------------------------------------------------

create policy document_relations_read_authenticated
on public.document_relations
for select
to authenticated
using (true);

create policy document_relations_admin_manage
on public.document_relations
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 30. DOCUMENT COUNTER POLICIES
-- ---------------------------------------------------------

create policy document_counters_admin_manage
on public.document_counters
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 31. INVENTORY MOVEMENT POLICIES
-- ---------------------------------------------------------

create policy inventory_movements_read_authenticated
on public.inventory_movements
for select
to authenticated
using (true);

create policy inventory_movements_admin_manage
on public.inventory_movements
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 32. RECEIVABLE POLICIES
-- ---------------------------------------------------------

create policy receivables_read_authenticated
on public.receivables
for select
to authenticated
using (true);

create policy receivables_admin_manage
on public.receivables
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 33. PAYMENT POLICIES
-- ---------------------------------------------------------

create policy payments_read_authenticated
on public.payments
for select
to authenticated
using (true);

create policy payments_admin_manage
on public.payments
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 34. PAYMENT ALLOCATION POLICIES
-- ---------------------------------------------------------

create policy payment_allocations_read_authenticated
on public.payment_allocations
for select
to authenticated
using (true);

create policy payment_allocations_admin_manage
on public.payment_allocations
for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));


-- 35. DATABASE PERMISSIONS
-- ---------------------------------------------------------

grant usage on schema public to authenticated, service_role;

grant select, insert, update, delete
on all tables in schema public
to authenticated;

grant all privileges
on all tables in schema public
to service_role;

grant select
on public.product_stock,
   public.document_totals,
   public.receivable_balances
to authenticated;
