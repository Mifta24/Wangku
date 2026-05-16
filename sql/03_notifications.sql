-- Notification inbox table for Wangku.
-- Run this after the base schema files.

create table if not exists public.notifications (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null default 'system',
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_created
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "Users can read own notifications" on public.notifications;
create policy "Users can read own notifications"
on public.notifications
for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert own notifications" on public.notifications;
create policy "Users can insert own notifications"
on public.notifications
for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can delete own notifications" on public.notifications;
create policy "Users can delete own notifications"
on public.notifications
for delete
using (auth.uid() = user_id);
