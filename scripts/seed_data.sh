#!/usr/bin/env bash
# Seed DynamoDB with sample multi-tenant data.
#
# Reads table name and region from Terraform outputs automatically,
# or accepts them as flags.
#
# Usage:
#   ./scripts/seed_data.sh                          # auto-detect from terraform outputs
#   ./scripts/seed_data.sh --table-name my-table    # explicit table name
#   ./scripts/seed_data.sh --clear                  # clear existing data first
#   ./scripts/seed_data.sh --tenants t1 t2 t3       # custom tenant list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Defaults — will be overridden by terraform outputs or flags
TABLE_NAME=""
REGION="us-east-1"
EXTRA_ARGS=()

# Parse flags, forwarding unknown ones to the Python script
while [[ $# -gt 0 ]]; do
  case "$1" in
    --table-name)  TABLE_NAME="$2"; shift 2 ;;
    --region)      REGION="$2"; shift 2 ;;
    *)             EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# Auto-detect from Terraform outputs if not provided
if [[ -z "$TABLE_NAME" ]]; then
  echo "Reading table name from Terraform outputs..."
  if TABLE_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw dynamodb_table_name 2>/dev/null); then
    echo "  Table: $TABLE_NAME"
  else
    echo "Error: Could not read dynamodb_table_name from Terraform outputs."
    echo "Either deploy infrastructure first or pass --table-name explicitly."
    exit 1
  fi
fi

if REGION_FROM_TF=$(terraform -chdir="$TERRAFORM_DIR" output -raw aws_region 2>/dev/null); then
  REGION="$REGION_FROM_TF"
fi

echo "Seeding table '$TABLE_NAME' in region '$REGION'"
echo ""

python3 "$SCRIPT_DIR/seed_dynamodb.py" \
  --table-name "$TABLE_NAME" \
  --region "$REGION" \
  "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
