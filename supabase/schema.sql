-- FORMA trainer site schema for Supabase PostgreSQL
-- Run this file in Supabase Dashboard -> SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
create or replace function public.is_site_admin()
returns boolean language sql stable security definer
set search_path = public
as $$ select exists(select 1 from public.admin_users where user_id = auth.uid()); $$;
revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  full_name text not null default 'Имя Тренера',
  specialization text not null default 'Персональный тренер',
  biography text not null default '',
  experience text not null default '',
  education text not null default '',
  achievements text not null default '',
  photo_url text,
  contact_details jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  description text not null default '',
  price numeric(10,2) check (price is null or price >= 0),
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),
  format text not null default 'individual',
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  client_name text not null check (char_length(trim(client_name)) between 1 and 100),
  phone text not null check (char_length(trim(phone)) between 3 and 120),
  email text check (email is null or char_length(email) <= 254),
  service_title text not null check (char_length(trim(service_title)) between 1 and 150),
  preferred_date date,
  preferred_time time,
  comment text check (comment is null or char_length(comment) <= 1500),
  status text not null default 'new' check (status in ('new','in_progress','confirmed','completed','cancelled')),
  created_at timestamptz not null default now()
);
create index if not exists bookings_created_at_idx on public.bookings(created_at desc);
create index if not exists bookings_status_idx on public.bookings(status);
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  client_name text not null,
  review_text text not null,
  rating integer not null default 5 check (rating between 1 and 5),
  photo_url text,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.gallery (
  id uuid primary key default gen_random_uuid(),
  image_url text not null,
  title text not null default '',
  description text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create table if not exists public.site_settings (
  id uuid primary key default gen_random_uuid(),
  setting_key text not null unique,
  setting_value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.services enable row level security;
alter table public.bookings enable row level security;
alter table public.reviews enable row level security;
alter table public.gallery enable row level security;
alter table public.site_settings enable row level security;

-- Remove only policies with these names so the script can be safely re-run.
drop policy if exists "admin users can read own admin membership" on public.admin_users;
create policy "admin users can read own admin membership" on public.admin_users
for select to authenticated using (user_id = auth.uid());

drop policy if exists "public read trainer profile" on public.profiles;
create policy "public read trainer profile" on public.profiles
for select to anon, authenticated using (true);
drop policy if exists "admins manage trainer profile" on public.profiles;
create policy "admins manage trainer profile" on public.profiles
for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "public read active services" on public.services;
create policy "public read active services" on public.services
for select to anon, authenticated using (is_active = true or public.is_site_admin());
drop policy if exists "admins manage services" on public.services;
create policy "admins manage services" on public.services
for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "public submit booking" on public.bookings;
create policy "public submit booking" on public.bookings
for insert to anon, authenticated
with check (
  status = 'new'
  and char_length(trim(client_name)) between 1 and 100
  and char_length(trim(phone)) between 3 and 120
  and char_length(trim(service_title)) between 1 and 150
  and (comment is null or char_length(comment) <= 1500)
);
drop policy if exists "admins manage bookings" on public.bookings;
create policy "admins manage bookings" on public.bookings
for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "public read published reviews" on public.reviews;
create policy "public read published reviews" on public.reviews
for select to anon, authenticated using (is_published = true or public.is_site_admin());
drop policy if exists "admins manage reviews" on public.reviews;
create policy "admins manage reviews" on public.reviews
for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "public read gallery" on public.gallery;
create policy "public read gallery" on public.gallery
for select to anon, authenticated using (true);
drop policy if exists "admins manage gallery" on public.gallery;
create policy "admins manage gallery" on public.gallery
for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "public read site settings" on public.site_settings;
create policy "public read site settings" on public.site_settings
for select to anon, authenticated using (true);
drop policy if exists "admins manage site settings" on public.site_settings;
create policy "admins manage site settings" on public.site_settings
for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());


-- Initial editable demo services. Re-running this schema does not overwrite later edits.
insert into public.services (title, slug, description, price, duration_minutes, format, is_active)
values
 ('Персональная тренировка','personal-training','Занятие один на один: техника, нагрузка и упражнения с учётом твоего уровня.',2000,60,'individual',true),
 ('Онлайн-тренировка','online-training','Дистанционное занятие с обратной связью и рекомендациями по технике.',1500,60,'online',true),
 ('Индивидуальная программа','individual-program','Структурированный план тренировок под цели и доступное оборудование.',3000,null,'program',true),
 ('Онлайн-сопровождение','online-support','План, регулярные корректировки и поддержка по согласованному графику.',5000,null,'support',true),
 ('Консультация','consultation','Обсудим цели, опыт и подберём подходящий формат занятий.',1000,45,'individual',true),
 ('Пакет тренировок','training-package','Регулярные занятия по плану с возможностью отслеживать прогресс.',null,null,'individual',true)
on conflict (slug) do nothing;

-- Important: create an auth user first, then insert that user's UUID into admin_users
-- from the SQL Editor (example below; replace the UUID with the real auth.users.id):
-- insert into public.admin_users(user_id) values ('YOUR-AUTH-USER-UUID');
