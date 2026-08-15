-- KZ Prestador mobile media + chat push support.
-- Run this in the Supabase SQL editor for project mtsqeomctrqfyekyzapc.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('Profile_Images', 'Profile_Images', true, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('Vehicle_Photos', 'Vehicle_Photos', true, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.vehicle_photos (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  photo_url text not null,
  photo_type text not null default 'general',
  created_at timestamptz not null default now()
);

create index if not exists idx_vehicle_photos_vehicle_id
  on public.vehicle_photos(vehicle_id, created_at desc);

create table if not exists public.driver_profile_photos (
  id uuid primary key default gen_random_uuid(),
  driver_profile_id uuid not null references public.driver_profiles(id) on delete cascade,
  photo_url text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_driver_profile_photos_driver_profile_id
  on public.driver_profile_photos(driver_profile_id, created_at desc);

alter table public.vehicle_photos enable row level security;
alter table public.driver_profile_photos enable row level security;

drop policy if exists vehicle_photos_select_all on public.vehicle_photos;
create policy vehicle_photos_select_all
  on public.vehicle_photos for select
  using (true);

drop policy if exists vehicle_photos_insert_owner on public.vehicle_photos;
create policy vehicle_photos_insert_owner
  on public.vehicle_photos for insert
  with check (
    exists (
      select 1
      from public.vehicles v
      join public.driver_profiles dp on dp.id = v.driver_profile_id
      join public.provider_profiles pp on pp.id = dp.provider_profile_id
      where v.id = vehicle_photos.vehicle_id
        and pp.user_id = auth.uid()
    )
  );

drop policy if exists driver_profile_photos_select_all on public.driver_profile_photos;
create policy driver_profile_photos_select_all
  on public.driver_profile_photos for select
  using (true);

drop policy if exists driver_profile_photos_insert_owner on public.driver_profile_photos;
create policy driver_profile_photos_insert_owner
  on public.driver_profile_photos for insert
  with check (
    exists (
      select 1
      from public.driver_profiles dp
      join public.provider_profiles pp on pp.id = dp.provider_profile_id
      where dp.id = driver_profile_photos.driver_profile_id
        and pp.user_id = auth.uid()
    )
  );

drop policy if exists profile_images_public_read on storage.objects;
create policy profile_images_public_read
  on storage.objects for select
  using (bucket_id = 'Profile_Images');

drop policy if exists vehicle_photos_public_read on storage.objects;
create policy vehicle_photos_public_read
  on storage.objects for select
  using (bucket_id = 'Vehicle_Photos');

drop policy if exists profile_images_owner_write on storage.objects;
create policy profile_images_owner_write
  on storage.objects for insert
  with check (
    bucket_id = 'Profile_Images'
    and auth.role() = 'authenticated'
    and (
      name like 'users/' || auth.uid()::text || '/%'
      or exists (
        select 1
        from public.driver_profiles dp
        join public.provider_profiles pp on pp.id = dp.provider_profile_id
        where pp.user_id = auth.uid()
          and name like 'drivers/' || dp.id::text || '/%'
      )
    )
  );

drop policy if exists profile_images_owner_update on storage.objects;
create policy profile_images_owner_update
  on storage.objects for update
  using (
    bucket_id = 'Profile_Images'
    and auth.role() = 'authenticated'
    and (
      name like 'users/' || auth.uid()::text || '/%'
      or exists (
        select 1
        from public.driver_profiles dp
        join public.provider_profiles pp on pp.id = dp.provider_profile_id
        where pp.user_id = auth.uid()
          and name like 'drivers/' || dp.id::text || '/%'
      )
    )
  );

drop policy if exists vehicle_photos_owner_write on storage.objects;
create policy vehicle_photos_owner_write
  on storage.objects for insert
  with check (
    bucket_id = 'Vehicle_Photos'
    and auth.role() = 'authenticated'
    and exists (
      select 1
      from public.vehicles v
      join public.driver_profiles dp on dp.id = v.driver_profile_id
      join public.provider_profiles pp on pp.id = dp.provider_profile_id
      where pp.user_id = auth.uid()
        and name like 'vehicles/' || v.id::text || '/%'
    )
  );

create or replace function public.trigger_push_on_chat_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public, net, vault, pg_temp
as $$
declare
  v_webhook_secret text;
begin
  select decrypted_secret
    into v_webhook_secret
  from vault.decrypted_secrets
  where name = 'push_webhook_secret'
  order by created_at desc
  limit 1;

  if coalesce(v_webhook_secret, '') = '' then
    raise warning 'push_webhook_secret ausente; chat push ignorado para mensagem %', new.id;
    return new;
  end if;

  begin
    perform net.http_post(
      url := 'https://mtsqeomctrqfyekyzapc.supabase.co/functions/v1/send-fcm-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Push-Webhook-Secret', v_webhook_secret
      ),
      body := jsonb_build_object(
        'table', 'chat_messages',
        'event', 'INSERT',
        'new_record', jsonb_build_object(
          'id', new.id,
          'chat_room_id', new.chat_room_id,
          'sender_id', new.sender_id,
          'message', new.message
        )
      ),
      timeout_milliseconds := 10000
    );
  exception when others then
    raise warning 'chat push notification failed for message %: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists trg_push_on_chat_message_insert on public.chat_messages;

create trigger trg_push_on_chat_message_insert
  after insert on public.chat_messages
  for each row
  execute function public.trigger_push_on_chat_message_insert();
