# Estia Health — dbt + Snowflake Demo

A ready-to-run dbt project demonstrating a three-layer data architecture on Snowflake, using realistic aged care operational data.

Clone it, point it at your Snowflake account, and have a working pipeline in under five minutes.

---

## What you get

| Layer | Snowflake Schema | Materialisation | Description |
|---|---|---|---|
| **Raw** | `ESTIA_DEMO.RAW` | Tables | Source data — no transformations |
| **Silver** | `ESTIA_DEMO.SILVER` | Views | Cleaned, typed, enriched |
| **Gold** | `ESTIA_DEMO.GOLD` | Tables | Business-ready aggregates |

Seven dbt models, 39 automated data quality tests, full column-level documentation, and an optional Snowflake Task DAG that refreshes the pipeline on a schedule.

---

## Prerequisites

- Snowflake account (any edition, any cloud region)
- Python 3.8+
- A role with `CREATE DATABASE` privilege (e.g. `SYSADMIN` or `ACCOUNTADMIN`)

---

## Quick start

### 1. Clone the repo

```bash
git clone <repo-url>
cd estia_dbt_demo
```

### 2. Install dbt

```bash
pip install dbt-snowflake
```

### 3. Set environment variables

Find your Snowflake account identifier in Snowsight: bottom-left corner → hover your account name → copy the identifier (format: `orgname-accountname`).

```bash
export SNOWFLAKE_ACCOUNT=myorg-myaccount
export SNOWFLAKE_USER=your.name@company.com
```

> The default auth method is **SSO (browser login)**. dbt will open a browser window when you run `dbt debug`. To use username/password instead, see [Alternative auth](#alternative-auth) below.

### 4. Load the raw data

Run the setup script in Snowsight (copy-paste) **or** via SnowSQL:

```bash
snowsql -a $SNOWFLAKE_ACCOUNT -u $SNOWFLAKE_USER -f setup/01_raw_data.sql
```

This creates the `ESTIA_DEMO` database, three schemas (`RAW`, `SILVER`, `GOLD`), and loads five tables with ~215 rows of realistic aged care dummy data.

### 5. Run dbt

```bash
# Verify connection (opens browser for SSO)
dbt debug --profiles-dir .

# Build all models
dbt run --profiles-dir .

# Run all 39 data quality tests
dbt test --profiles-dir .
```

### 6. (Optional) Browse the docs

```bash
dbt docs generate --profiles-dir .
dbt docs serve
```

Opens a browser at `localhost:8080` with the full model lineage DAG and column-level descriptions.

---

## Optional: Snowflake Task DAG

To add a Snowflake Task graph that refreshes the pipeline on a 1-hour schedule, run the task setup script in Snowsight:

```
setup/02_tasks.sql
```

This creates three tasks in `ESTIA_DEMO.ORCHESTRATION`:

```
TASK_ROOT  (every hour)
    → TASK_SILVER  (refreshes all 5 staging views)
        → TASK_GOLD  (rebuilds both mart tables)
```

Trigger a manual run at any time:

```sql
EXECUTE TASK ESTIA_DEMO.ORCHESTRATION.TASK_ROOT;
```

Check run history:

```sql
SELECT name, state, completed_time
FROM TABLE(ESTIA_DEMO.information_schema.task_history(
    scheduled_time_range_start => DATEADD('minute', -10, CURRENT_TIMESTAMP()),
    result_limit => 20
))
WHERE database_name = 'ESTIA_DEMO'
ORDER BY scheduled_time DESC;
```

---

## Project structure

```
estia_dbt_demo/
├── .gitignore
├── README.md
├── dbt_project.yml          # Project config, materialisation settings
├── profiles.yml             # Snowflake connection (env vars, no secrets)
├── macros/
│   └── generate_schema_name.sql   # Ensures models land in SILVER/GOLD (not RAW_SILVER)
├── setup/
│   ├── 01_raw_data.sql      # Creates ESTIA_DEMO database + loads raw tables
│   └── 02_tasks.sql         # Creates the Snowflake Task DAG (optional)
└── models/
    ├── staging/
    │   ├── _sources.yml              # RAW schema declared as dbt source
    │   ├── _staging_models.yml       # Tests + docs for staging models
    │   ├── stg_facilities.sql
    │   ├── stg_residents.sql
    │   ├── stg_care_assessments.sql
    │   ├── stg_incidents.sql
    │   └── stg_invoices.sql
    └── marts/
        ├── _marts_models.yml         # Tests + docs for mart models
        ├── mart_resident_care_summary.sql
        └── mart_facility_kpis.sql
```

---

## Data model

### Raw tables (loaded by `setup/01_raw_data.sql`)

| Table | Rows | Description |
|---|---|---|
| `raw_facilities` | 5 | Five Estia facilities across VIC, NSW, SA, QLD |
| `raw_residents` | 30 | Resident demographics and admission history |
| `raw_care_assessments` | 60 | ACFI and InterRAI assessments with scores |
| `raw_incidents` | 40 | Incident reports (falls, medication errors, wounds) |
| `raw_invoices` | 80 | Monthly invoices by payer (Government / NDIS / Private) |

### Silver models (views in `ESTIA_DEMO.SILVER`)

| Model | Key enrichments |
|---|---|
| `stg_facilities` | State code normalisation |
| `stg_residents` | `age_years`, `care_days`, `is_active`, `is_deceased` |
| `stg_care_assessments` | `risk_band` (Low / Moderate / High) from score |
| `stg_incidents` | `is_high_severity` boolean |
| `stg_invoices` | `payment_status` (Paid / Overdue / Pending), `is_overdue`, split paid/outstanding amounts |

### Gold models (tables in `ESTIA_DEMO.GOLD`)

| Model | What it answers |
|---|---|
| `mart_resident_care_summary` | Per-resident: care days, risk band, incident history, billing position |
| `mart_facility_kpis` | Per-facility: occupancy %, avg care score, incidents per 100 bed-days, revenue |

---

## Alternative auth

**Username + password** — edit `profiles.yml` and swap Option A for Option B:

```yaml
# Comment out this line:
authenticator: externalbrowser

# Uncomment these lines:
password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
role: "{{ env_var('SNOWFLAKE_ROLE', 'SYSADMIN') }}"
```

Then set:

```bash
export SNOWFLAKE_PASSWORD=your_password
export SNOWFLAKE_ROLE=SYSADMIN
```

**Key pair auth** — generate a key pair, register the public key with your Snowflake user, then use `private_key_path` in `profiles.yml`. See the [dbt-snowflake docs](https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup#key-pair-authentication) for full instructions.

---

## Customising the target database

The default target is `ESTIA_DEMO`. To use a different database, set:

```bash
export SNOWFLAKE_DATABASE=MY_DATABASE
```

And update the database references in `setup/01_raw_data.sql` and `setup/02_tasks.sql` before running them (find-replace `ESTIA_DEMO` with your database name).

---

## dbt tests included

- `unique` + `not_null` on all primary keys
- `relationships` (foreign key integrity across staging models)
- `accepted_values` for `status`, `risk_band`, `severity`, `assessment_type`, `payer_type`, `payment_status`, `state`
