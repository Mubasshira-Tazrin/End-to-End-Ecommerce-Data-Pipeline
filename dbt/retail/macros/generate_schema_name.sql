{#
  Override dbt's default schema-naming.

  By default dbt builds a model's schema as  <target.schema>_<custom_schema>
  (e.g. "silver_gold"), which would give us mangled names. Here we use the
  custom schema name VERBATIM, so `+schema: silver` -> schema "silver" and
  `+schema: gold` -> schema "gold". Models with no +schema fall back to the
  profile's target schema.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- if custom_schema_name is none -%}
        {{ target.schema | trim }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
