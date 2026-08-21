{#
  Macro: dbt_surrogate_key
  Builds a deterministic surrogate key by hashing one or more columns.
  In a real project you'd use dbt_utils.generate_surrogate_key (from the
  dbt_utils package via packages.yml + `dbt deps`); this local version keeps
  the repo dependency-free and shows what that macro does under the hood.

  Usage:  {{ dbt_surrogate_key(['investor_id']) }}
          {{ dbt_surrogate_key(['investor_id','fund_id']) }}
#}
{% macro dbt_surrogate_key(field_list) %}
    md5(
        {%- for f in field_list %}
        coalesce(cast({{ f }} as varchar), '_null_')
        {%- if not loop.last %} || '-' || {% endif %}
        {%- endfor %}
    )
{% endmacro %}
