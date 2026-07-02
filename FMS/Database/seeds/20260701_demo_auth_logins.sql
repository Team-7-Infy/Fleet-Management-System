-- Demo auth logins for the seeded Fleet Manager data.
-- Run this in Supabase SQL Editor after the main demo seed.
-- Password for all three accounts: Fms@123456

begin;

create extension if not exists pgcrypto with schema extensions;

delete from auth.identities
where user_id in (
    '11000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000101',
    '11000000-0000-0000-0000-000000000201'
)
or user_id in (
    select id
    from auth.users
    where email in (
        'kavya.manager@fms.local',
        'rohan.sharma@fms.local',
        'suresh.yadav@fms.local'
    )
);

delete from auth.users
where id in (
    '11000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000101',
    '11000000-0000-0000-0000-000000000201'
)
or email in (
    'kavya.manager@fms.local',
    'rohan.sharma@fms.local',
    'suresh.yadav@fms.local'
);

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
values
    (
        '00000000-0000-0000-0000-000000000000',
        '11000000-0000-0000-0000-000000000001',
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
    ),
    (
        '00000000-0000-0000-0000-000000000000',
        '11000000-0000-0000-0000-000000000101',
        'authenticated',
        'authenticated',
        'rohan.sharma@fms.local',
        extensions.crypt('Fms@123456', extensions.gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"name":"Rohan Sharma"}'::jsonb,
        now(),
        now(),
        false
    ),
    (
        '00000000-0000-0000-0000-000000000000',
        '11000000-0000-0000-0000-000000000201',
        'authenticated',
        'authenticated',
        'suresh.yadav@fms.local',
        extensions.crypt('Fms@123456', extensions.gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"name":"Suresh Yadav"}'::jsonb,
        now(),
        now(),
        false
    );

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
values
    (
        '11000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000001',
        '{"sub":"11000000-0000-0000-0000-000000000001","email":"kavya.manager@fms.local","email_verified":true,"phone_verified":false}'::jsonb,
        'email',
        now(),
        now(),
        now()
    ),
    (
        '11000000-0000-0000-0000-000000000101',
        '11000000-0000-0000-0000-000000000101',
        '11000000-0000-0000-0000-000000000101',
        '{"sub":"11000000-0000-0000-0000-000000000101","email":"rohan.sharma@fms.local","email_verified":true,"phone_verified":false}'::jsonb,
        'email',
        now(),
        now(),
        now()
    ),
    (
        '11000000-0000-0000-0000-000000000201',
        '11000000-0000-0000-0000-000000000201',
        '11000000-0000-0000-0000-000000000201',
        '{"sub":"11000000-0000-0000-0000-000000000201","email":"suresh.yadav@fms.local","email_verified":true,"phone_verified":false}'::jsonb,
        'email',
        now(),
        now(),
        now()
    );

do $$
declare
    login_user_ids uuid[] := array[
        '11000000-0000-0000-0000-000000000001'::uuid,
        '11000000-0000-0000-0000-000000000101'::uuid,
        '11000000-0000-0000-0000-000000000201'::uuid
    ];
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
    auth.users.email_confirmed_at is not null as auth_confirmed
from public.users
join auth.users on auth.users.id = public.users.userid
where public.users.userid in (
    '11000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000101',
    '11000000-0000-0000-0000-000000000201'
)
order by public.users.role;
