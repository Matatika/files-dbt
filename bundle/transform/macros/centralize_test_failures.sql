{% macro centralize_test_failures(results) %}

    {# Only proceed if the command is 'test', the env var is true, and the dbt adapter is snowflake. #}
    {% if flags.WHICH == 'test' and flags.STORE_FAILURES and env_var('STORE_TEST_RESULTS', 'false') == 'true' and adapter.type() == 'snowflake'%}

      {%- set test_results = [] -%}
      {%- for result in results -%}
        {%- if result.node.resource_type == 'test' and result.status != 'skipped' and result.status != 'error' -%}
          {%- do test_results.append(result) -%}
        {%- endif -%}
      {%- endfor -%}

      {%- if test_results | length > 0 -%}
      
        {%- set central_tbl -%} {{ var('tests_schema') }}.test_failure_central {%- endset -%}
        
        {{ log("Centralizing test failures in " + central_tbl, info = true) if execute }}

        {% set table_exists_query %}
          show tables like 'test_failure_central' in schema {{ var('tests_schema') }}
        {% endset %}

        {% set results = run_query(table_exists_query) %}
        {% if execute %}
          {% set table_exists = results and results.rows | length > 0 %}
        {% endif %}

        {% if table_exists %}
          {{ log("Table " + central_tbl + " exists, including its records.", info = true) }}
        {% else %}
          {{ log("Table " + central_tbl + " does not exist, creating table.", info = true) }}
        {% endif %}

        create or replace table {{ central_tbl }} as (

        {% if table_exists %}
          select *
          from {{ central_tbl }}
          union all
        {% endif %}

        {% for result in test_results %}

            select
            '{{ result.node.unique_id }}' as test_name
            , current_timestamp as test_run_time
            , object_construct_keep_null(*) as test_failures_json
            from {{ result.node.relation_name }}

            {{ "union all" if not loop.last }}

        {% endfor %}

      {%- endif -%}
      
      )
    {% else %}
      {{ log("Storing test results disabled, doing nothing.", info = true) }}
    {% endif %}

{% endmacro %}