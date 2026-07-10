-- DealBoard cloud sharing — run once in the Supabase SQL editor.
-- Two tables mirror the app's deals and establishments, keyed by a group code.

create table if not exists public.shared_establishments (
    id          uuid primary key,
    group_code  text not null,
    updated_at  timestamptz not null,
    is_deleted  boolean not null default false,
    payload     jsonb not null
);
create index if not exists shared_establishments_group_idx
    on public.shared_establishments (group_code, updated_at);

create table if not exists public.shared_deals (
    id          uuid primary key,
    group_code  text not null,
    updated_at  timestamptz not null,
    is_deleted  boolean not null default false,
    payload     jsonb not null
);
create index if not exists shared_deals_group_idx
    on public.shared_deals (group_code, updated_at);

-- Row Level Security: allow the anon key to read/write.
-- NOTE: access is gated by knowing the group code, not by RLS — anyone with the
-- app's anon key could query other codes. Fine for casual friend sharing; do not
-- store anything sensitive. (A future version could add a per-group secret.)
alter table public.shared_establishments enable row level security;
alter table public.shared_deals          enable row level security;

create policy "anon read/write establishments" on public.shared_establishments
    for all to anon using (true) with check (true);
create policy "anon read/write deals" on public.shared_deals
    for all to anon using (true) with check (true);
