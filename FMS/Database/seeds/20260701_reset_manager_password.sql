-- Manager login reset/check.
-- Run this in Supabase SQL Editor.
-- Login after this:
--   Email:    kavya.manager@fms.local
--   Password: Fms@123456

begin;

create extension if not exists pgcrypto with schema extensions;

do $$
declare
    manager_auth_id uuid;
begin
    select id
    into manager_auth_id
    from auth.users
    where lower(email) = lower('kavya.manager@fms.local')
    limit 1;

    if manager_auth_id is null then
        manager_auth_id := '11000000-0000-0000-0000-000000000001';

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
        values (
            '00000000-0000-0000-0000-000000000000',
            manager_auth_id,
            'authenticated',
            'authenticated',
            'kavya.manager@fms.local',
            extensions.crypt('Fms@123456', extensions.gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"name":"Kavya Rao"}'::jsonb,
            now(),
            now(),
            false
        );
    else
        update auth.users
        set
            aud = 'authenticated',
            role = 'authenticated',
            email = 'kavya.manager@fms.local',
            encrypted_password = extensions.crypt('Fms@123456', extensions.gen_salt('bf')),
            email_confirmed_at = coalesce(email_confirmed_at, now()),
            raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
            raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || '{"name":"Kavya Rao"}'::jsonb,
            updated_at = now(),
            is_sso_user = false
        where id = manager_auth_id;
    end if;

    delete from auth.identities
    where user_id = manager_auth_id
       or (provider = 'email' and identity_data ->> 'email' = 'kavya.manager@fms.local');

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
    values (
        manager_auth_id,
        manager_auth_id,
        manager_auth_id::text,
        jsonb_build_object(
            'sub', manager_auth_id::text,
            'email', 'kavya.manager@fms.local',
            'email_verified', true,
            'phone_verified', false
        ),
        'email',
        now(),
        now(),
        now()
    );

    update public.users
    set
        email = 'kavya.manager@fms.local',
        role = 'fleet_manager',
        f_name = 'Kavya',
        l_name = 'Rao',
        isactive = true,
        first_time_login = false
    where userid = '11000000-0000-0000-0000-000000000001'
       or lower(email) = lower('kavya.manager@fms.local');

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'confirmation_token'
    ) then
        execute 'update auth.users set confirmation_token = coalesce(confirmation_token, '''') where id = $1'
        using manager_auth_id;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'recovery_token'
    ) then
        execute 'update auth.users set recovery_token = coalesce(recovery_token, '''') where id = $1'
        using manager_auth_id;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'email_change'
    ) then
        execute 'update auth.users set email_change = coalesce(email_change, '''') where id = $1'
        using manager_auth_id;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'email_change_token_new'
    ) then
        execute 'update auth.users set email_change_token_new = coalesce(email_change_token_new, '''') where id = $1'
        using manager_auth_id;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'email_change_token_current'
    ) then
        execute 'update auth.users set email_change_token_current = coalesce(email_change_token_current, '''') where id = $1'
        using manager_auth_id;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'phone_change'
    ) then
        execute 'update auth.users set phone_change = coalesce(phone_change, '''') where id = $1'
        using manager_auth_id;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'phone_change_token'
    ) then
        execute 'update auth.users set phone_change_token = coalesce(phone_change_token, '''') where id = $1'
        using manager_auth_id;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'reauthentication_token'
    ) then
        execute 'update auth.users set reauthentication_token = coalesce(reauthentication_token, '''') where id = $1'
        using manager_auth_id;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'email_change_confirm_status'
    ) then
        execute 'update auth.users set email_change_confirm_status = coalesce(email_change_confirm_status, 0) where id = $1'
        using manager_auth_id;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'users' and column_name = 'is_anonymous'
    ) then
        execute 'update auth.users set is_anonymous = coalesce(is_anonymous, false) where id = $1'
        using manager_auth_id;
    end if;
end $$;

commit;

select
    id,
    email,
    email_confirmed_at is not null as email_confirmed,
    coalesce(confirmation_token, '') = '' as confirmation_token_ok,
    coalesce(recovery_token, '') = '' as recovery_token_ok,
    coalesce(email_change_token_new, '') = '' as email_change_token_ok,
    encrypted_password = extensions.crypt('Fms@123456', encrypted_password) as password_ok
from auth.users
where lower(email) = lower('kavya.manager@fms.local');
