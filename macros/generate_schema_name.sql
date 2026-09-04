-- Override dbt's default schema name generation so that models land in exactly
-- the schema specified by +schema in dbt_project.yml (SILVER, GOLD) rather than
-- the default {target_schema}_{custom_schema} pattern.
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
