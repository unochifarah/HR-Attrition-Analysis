-- v_attrition_risk_score
-- Composite risk score for current employees
-- 
-- Scoring weights:
--   Overtime → +20 pts (strongest signal from Q3)
--   Low job sat → +20 pts
--   Low WLB → +15 pts
--   Stuck (no promo) → +15 pts
--   Low env sat → +10 pts
--   Job hopper → +10 pts
--   Long commute → +10 pts
--
-- Tiers: High = 60+, Medium = 30–59, Low = <30

CREATE OR REPLACE VIEW v_attrition_risk_score AS
WITH scored AS (
  SELECT
    employee_number,
    job_role,
    department,
    age,
    monthly_income,
    years_at_company,
    attrition,
    over_time,
    (CASE WHEN over_time = 'Yes' THEN 20 ELSE 0 END
   + CASE WHEN job_satisfaction <= 2 THEN 20 ELSE 0 END
   + CASE WHEN work_life_balance <= 2 THEN 15 ELSE 0 END
   + CASE WHEN environment_satisfaction <= 2 THEN 10 ELSE 0 END
   + CASE WHEN years_since_last_promotion >= 5 THEN 15 ELSE 0 END
   + CASE WHEN num_companies_worked >= 5 THEN 10 ELSE 0 END
   + CASE WHEN distance_from_home >= 25 THEN 10 ELSE 0 END
    ) AS raw_score,
    PERCENT_RANK() OVER (
      PARTITION BY department
      ORDER BY monthly_income
    ) AS income_pctile_in_dept
  FROM hr_attrition
)
SELECT *,
  CASE
    WHEN raw_score >= 60 THEN 'High'
    WHEN raw_score >= 30 THEN 'Medium'
    ELSE 'Low'
  END AS risk_tier,
  ROUND(monthly_income * 12 * 1.5, 0) AS estimated_replacement_cost
FROM scored
ORDER BY raw_score DESC;