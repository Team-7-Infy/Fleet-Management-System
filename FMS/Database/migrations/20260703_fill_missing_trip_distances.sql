alter table public.trips
add column if not exists distance double precision;

update public.trips
set distance = case
    when lower(coalesce(startlocation, '')) like '%haridwar%'
        and lower(coalesce(endlocation, '')) like '%bengaluru%' then 2015
    when lower(coalesce(startlocation, '')) like '%bengaluru%'
        and lower(coalesce(endlocation, '')) like '%surat%' then 1260
    when lower(coalesce(startlocation, '')) like '%gurugram%'
        and lower(coalesce(endlocation, '')) like '%jaipur%' then 281
    when lower(coalesce(startlocation, '')) like '%delhi%'
        and lower(coalesce(endlocation, '')) like '%chandigarh%' then 244
    when lower(coalesce(startlocation, '')) like '%dehradun%'
        and lower(coalesce(endlocation, '')) like '%haridwar%' then 53
    when lower(coalesce(startlocation, '')) like '%noida%'
        and lower(coalesce(endlocation, '')) like '%agra%' then 211
    when lower(coalesce(startlocation, '')) like '%jaipur%'
        and lower(coalesce(endlocation, '')) like '%ajmer%' then 135
    when lower(coalesce(startlocation, '')) like '%noida%'
        and lower(coalesce(endlocation, '')) like '%lucknow%' then 536
    when lower(coalesce(startlocation, '')) like '%chandigarh%'
        and lower(coalesce(endlocation, '')) like '%shimla%' then 112
    when lower(coalesce(startlocation, '')) like '%gurugram%'
        and lower(coalesce(endlocation, '')) like '%delhi%' then 28
    when lower(coalesce(startlocation, '')) like '%ludhiana%'
        and lower(coalesce(endlocation, '')) like '%ambala%' then 113
    when lower(coalesce(startlocation, '')) like '%lucknow%'
        and lower(coalesce(endlocation, '')) like '%kanpur%' then 90
    when lower(coalesce(startlocation, '')) like '%delhi%'
        and lower(coalesce(endlocation, '')) like '%meerut%' then 82
    when lower(coalesce(startlocation, '')) like '%gurugram%'
        and lower(coalesce(endlocation, '')) like '%faridabad%' then 37
    when lower(coalesce(startlocation, '')) = lower(coalesce(endlocation, '')) then 8
    else round((35 + random() * 850)::numeric, 0)::double precision
end
where distance is null;
