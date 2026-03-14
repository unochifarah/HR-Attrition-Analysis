-- Q1: Attrition by department, age band, and job role
SELECT
  department,
  CASE
    WHEN age < 25 THEN 'Under 25'
    WHEN age < 35 THEN '25–34'
    WHEN age < 45 THEN '35–44'
    ELSE '45+'
  END AS age_band,
  job_role,
  COUNT(*) AS total,
  SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) AS left_count,
  ROUND(
    100.0 * SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END)
    / COUNT(*), 1) AS attrition_rate
FROM hr_attrition
GROUP BY department, age_band, job_role
ORDER BY attrition_rate DESC;

-- Q2: Department attrition ranking
WITH dept_stats AS (
  SELECT
    department,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) AS left_count,
    ROUND(
      100.0 * SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END)
      / COUNT(*), 2) AS attrition_rate,
    ROUND(AVG(monthly_income), 0) AS avg_salary,
    ROUND(AVG(job_satisfaction), 2) AS avg_satisfaction
  FROM hr_attrition
  GROUP BY department
),
dept_ranked AS (
  SELECT *,
    DENSE_RANK() OVER (ORDER BY attrition_rate DESC) AS risk_rank,
    ROUND(attrition_rate - AVG(attrition_rate) OVER (), 2) AS vs_company_avg
  FROM dept_stats
)
SELECT * FROM dept_ranked
ORDER BY risk_rank;

-- Q3: Driver comparison — leavers vs stayers
SELECT
  attrition,
  COUNT(*) AS headcount,
  ROUND(AVG(monthly_income), 0) AS avg_income,
  ROUND(AVG(job_satisfaction), 2) AS avg_job_satisfaction,
  ROUND(AVG(work_life_balance), 2) AS avg_wlb,
  ROUND(AVG(environment_satisfaction), 2) AS avg_env_satisfaction,
  ROUND(AVG(relationship_satisfaction), 2) AS avg_relationship,
  ROUND(AVG(years_since_last_promotion), 2) AS avg_yrs_since_promo,
  ROUND(AVG(distance_from_home), 2) AS avg_distance,
  SUM(CASE WHEN over_time = 'Yes' THEN 1 ELSE 0 END) AS ot_count,
  ROUND(
    100.0 * SUM(CASE WHEN over_time = 'Yes' THEN 1 ELSE 0 END)
    / COUNT(*), 1) AS ot_pct
FROM hr_attrition
GROUP BY attrition
ORDER BY attrition DESC;

-- Q4: Cost of attrition by role and department
WITH role_counts AS (
  SELECT
    job_role,
    department,
    COUNT(*) AS headcount,
    SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) AS attrited,
    ROUND(AVG(monthly_income), 0) AS avg_monthly_income
  FROM hr_attrition
  GROUP BY job_role, department
),
cost_calc AS (
  SELECT *,
    ROUND(avg_monthly_income * 12, 0) AS avg_annual_salary,
    ROUND(avg_monthly_income * 12 * 1.5, 0) AS cost_per_replacement,
    ROUND(attrited * (avg_monthly_income * 12 * 1.5), 0) AS total_attrition_cost
  FROM role_counts
),
dept_cost_rollup AS (
  SELECT
    department,
    SUM(total_attrition_cost) AS dept_total_cost,
    SUM(attrited) AS dept_total_attrited
  FROM cost_calc
  GROUP BY department
)
SELECT
  c.department,
  c.job_role,
  c.headcount,
  c.attrited,
  c.avg_annual_salary,
  c.cost_per_replacement,
  c.total_attrition_cost,
  d.dept_total_cost,
  ROUND(
    100.0 * c.total_attrition_cost / NULLIF(d.dept_total_cost, 0)
  , 1) AS pct_of_dept_cost
FROM cost_calc c
JOIN dept_cost_rollup d USING (department)
ORDER BY c.total_attrition_cost DESC;

-- Q4b: Company-wide KPI totals
SELECT
  SUM(CASE WHEN attrition = 'Yes' 
      THEN monthly_income * 12 * 1.5 ELSE 0 END) AS total_cost_of_attrition,
  COUNT(*) FILTER (WHERE attrition = 'Yes') AS total_attrited,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE attrition = 'Yes')
    / COUNT(*), 2) AS overall_attrition_rate
FROM hr_attrition;