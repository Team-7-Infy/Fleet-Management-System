#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_FILE="$SCRIPT_DIR/seeds/20260701_full_demo_dataset.sql"

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "Set SUPABASE_DB_URL to your Supabase Postgres connection string." >&2
  echo "Example:" >&2
  echo "  SUPABASE_DB_URL='postgresql://postgres:password@host:5432/postgres' $0" >&2
  exit 1
fi

psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$SEED_FILE"
