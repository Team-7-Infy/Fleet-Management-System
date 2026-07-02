begin;

alter table public.users
    add column if not exists avatarurl text;

update public.users
set avatarurl = 'https://i.pravatar.cc/240?u=' || coalesce(nullif(email, ''), userid::text)
where role in ('driver', 'maintenance_personnel', 'fleet_manager')
  and nullif(avatarurl, '') is null;

commit;
