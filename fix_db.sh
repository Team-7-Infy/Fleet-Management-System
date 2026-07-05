#!/bin/bash
export URL="https://vbmlbvngzcttjnbxydkk.supabase.co/rest/v1"
export KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZibWxidm5nemN0dGpuYnh5ZGtrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjIwMDEwMCwiZXhwIjoyMDk3Nzc2MTAwfQ.LaUUvN5XpSk-mPnoBoQryso-jvw6omfIuYP-D2Au8d4"

# Link tasks to a vehicle
curl -s -X POST "$URL/task_vehicles" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -H "Prefer: return=minimal" \
  -d '[
    {"taskid": "5b74d917-9459-4292-a979-c0f63df047e7", "vin": "51000000-0000-0000-0000-000000000001"},
    {"taskid": "f5288aa8-38cc-4fac-a090-9bd27d1b1443", "vin": "51000000-0000-0000-0000-000000000002"},
    {"taskid": "d77954e8-b1d6-44ee-a874-31e9e3310110", "vin": "51000000-0000-0000-0000-000000000003"}
  ]'

# Update titles for tasks with null titles
curl -s -X PATCH "$URL/maintenance_task?taskid=eq.5b74d917-9459-4292-a979-c0f63df047e7" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"title": "Engine Overhaul"}'

curl -s -X PATCH "$URL/maintenance_task?taskid=eq.f5288aa8-38cc-4fac-a090-9bd27d1b1443" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"title": "Brake Pad Replacement"}'

curl -s -X PATCH "$URL/maintenance_task?taskid=eq.d77954e8-b1d6-44ee-a874-31e9e3310110" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"title": "Routine Service"}'

echo "Database updated."
