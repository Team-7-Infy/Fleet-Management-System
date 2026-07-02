-- Demo auth logins for the seeded Fleet Manager data.
-- Run this in Supabase SQL Editor after the main demo seed.
-- Password for every account below: Fms@123456

begin;

create extension if not exists pgcrypto with schema extensions;

create temporary table demo_auth_accounts (
    user_id uuid primary key,
    email text not null unique,
    display_name text not null,
    role text not null
) on commit preserve rows;

insert into demo_auth_accounts (user_id, email, display_name, role)
values
    ('11000000-0000-0000-0000-000000000001', 'kavya.manager@fms.local', 'Kavya Rao', 'fleet_manager'),
    ('11000000-0000-0000-0000-000000000101', 'rohan.sharma@fms.local', 'Rohan Sharma', 'driver'),
    ('11000000-0000-0000-0000-000000000102', 'meera.joshi@fms.local', 'Meera Joshi', 'driver'),
    ('11000000-0000-0000-0000-000000000103', 'arjun.rawat@fms.local', 'Arjun Rawat', 'driver'),
    ('11000000-0000-0000-0000-000000000104', 'farhan.ali@fms.local', 'Farhan Ali', 'driver'),
    ('11000000-0000-0000-0000-000000000105', 'isha.bansal@fms.local', 'Isha Bansal', 'driver'),
    ('11000000-0000-0000-0000-000000000106', 'manav.singh@fms.local', 'Manav Singh', 'driver'),
    ('11000000-0000-0000-0000-000000000107', 'naina.kapoor@fms.local', 'Naina Kapoor', 'driver'),
    ('11000000-0000-0000-0000-000000000108', 'dev.malik@fms.local', 'Dev Malik', 'driver'),
    ('11000000-0000-0000-0000-000000000109', 'pranav.sethi@fms.local', 'Pranav Sethi', 'driver'),
    ('11000000-0000-0000-0000-000000000110', 'tara.nair@fms.local', 'Tara Nair', 'driver'),
    ('11000000-0000-0000-0000-000000000112', 'zoya.khan@fms.local', 'Zoya Khan', 'driver'),
    ('11000000-0000-0000-0000-000000000201', 'suresh.yadav@fms.local', 'Suresh Yadav', 'maintenance_personnel');

delete from auth.identities
where user_id in (select user_id from demo_auth_accounts)
   or user_id in (
        select id
        from auth.users
        where lower(email) in (select lower(email) from demo_auth_accounts)
   );

delete from auth.users
where id in (select user_id from demo_auth_accounts)
   or lower(email) in (select lower(email) from demo_auth_accounts);

insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    is_sso_user
)
select
    '00000000-0000-0000-0000-000000000000',
    user_id,
    'authenticated',
    'authenticated',
    email,
    extensions.crypt('Fms@123456', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('name', display_name),
    now(),
    now(),
    false
from demo_auth_accounts;

insert into auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
)
select
    user_id,
    user_id,
    user_id::text,
    jsonb_build_object(
        'sub', user_id::text,
        'email', email,
        'email_verified', true,
        'phone_verified', false
    ),
    'email',
    now(),
    now(),
    now()
from demo_auth_accounts;

do $$
declare
    login_user_ids uuid[] := ARRAY(SELECT user_id FROM demo_auth_accounts);
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'confirmation_token'
    ) then
        update auth.users set confirmation_token = coalesce(confirmation_token, '') where id = any(login_user_ids);
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'recovery_token'
    ) then
        update auth.users set recovery_token = coalesce(recovery_token, '') where id = any(login_user_ids);
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'email_change'
    ) then
        update auth.users set email_change = coalesce(email_change, '') where id = any(login_user_ids);
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'email_change_token_new'
    ) then
        update auth.users set email_change_token_new = coalesce(email_change_token_new, '') where id = any(login_user_ids);
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'email_change_token_current'
    ) then
        update auth.users set email_change_token_current = coalesce(email_change_token_current, '') where id = any(login_user_ids);
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'phone_change'
    ) then
        update auth.users set phone_change = coalesce(phone_change, '') where id = any(login_user_ids);
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'phone_change_token'
    ) then
        update auth.users set phone_change_token = coalesce(phone_change_token, '') where id = any(login_user_ids);
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'reauthentication_token'
    ) then
        update auth.users set reauthentication_token = coalesce(reauthentication_token, '') where id = any(login_user_ids);
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'email_change_confirm_status'
    ) then
        update auth.users set email_change_confirm_status = coalesce(email_change_confirm_status, 0) where id = any(login_user_ids);
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'is_anonymous'
    ) then
        update auth.users set is_anonymous = coalesce(is_anonymous, false) where id = any(login_user_ids);
    end if;
end $$;

commit;

select
    public.users.role,
    public.users.email,
    auth.users.email_confirmed_at is not null as auth_confirmed,
    auth.users.encrypted_password = extensions.crypt('Fms@123456', auth.users.encrypted_password) as password_ok
from public.users
join auth.users on auth.users.id = public.users.userid
where public.users.userid in (select user_id from demo_auth_accounts)
order by public.users.role, public.users.email;
