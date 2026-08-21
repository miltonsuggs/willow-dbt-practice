{#
  Macro: signed_cash_flow
  A reusable CASE expression for the cash-flow sign convention, so the logic
  lives in ONE place. Calls look like: {{ signed_cash_flow('txn_type','amount') }}

  This is the everyday use of Jinja macros in dbt: DRY up repeated SQL snippets.
  (Investor's cash perspective: calls/fees out (-), distributions/redemptions in (+),
   subscriptions are commitments, not cash (0).)
#}
{% macro signed_cash_flow(type_col, amount_col) %}
    case
        when {{ type_col }} in ('capital_call','fee')        then -{{ amount_col }}
        when {{ type_col }} in ('distribution','redemption')  then  {{ amount_col }}
        else 0
    end
{% endmacro %}
