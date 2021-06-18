CREATE TABLE Summary_of_Hours_by_HOC_Item_csv (
    hoc_item TEXT,
    annex_2_definition TEXT,
    functional_team_department TEXT,
    project_job_code TEXT,
    employee_id TEXT,
    sum_of_time_hours DECIMAL(6, 1)
);


CREATE TABLE Summary_of_Hours_by_HOC_Item_previous_months_csv (
    hoc_item TEXT,
    annex_2_definition TEXT,
    functional_team_department TEXT,
    project_job_code TEXT,
    employee_id TEXT,
    sum_of_time_hours DECIMAL(6, 1)
);


CREATE TABLE Employee_Category_Summary (
    employee_category TEXT,
    hourly_rate DECIMAL(6, 2),
    hours_worked DECIMAL(6, 1),
    monthly_total DECIMAL(10, 2),
    PRIMARY KEY (employee_category)
);


CREATE VIEW Summary_of_Hours_by_HOC_Item_csv_union AS
SELECT * FROM Summary_of_Hours_by_HOC_Item_csv
UNION ALL
SELECT * FROM Summary_of_Hours_by_HOC_Item_previous_months_csv;


-- Extraer la relación entre las columnas `hoc_item` y
-- `annex_2_definition` del CSV
CREATE MATERIALIZED VIEW hoc_item_annex_2_definition AS
SELECT
	hoc_item,
	max(annex_2_definition) annex_2_definition
FROM Summary_of_Hours_by_HOC_Item_csv_union
WHERE annex_2_definition NOT LIKE '% Total'
GROUP BY hoc_item
ORDER BY hoc_item;


CREATE MATERIALIZED VIEW Summary_of_Hours_by_HOC_Item AS
SELECT
	hoc_item,
	def.annex_2_definition,
	functional_team_department,
	project_job_code,
	employee_id,
	sum_of_time_hours
FROM Summary_of_Hours_by_HOC_Item_csv_union csv
INNER JOIN hoc_item_annex_2_definition def
	USING (hoc_item)
WHERE def.annex_2_definition NOT LIKE '% Total'
AND functional_team_department IS NOT NULL
AND employee_id IS NOT NULL
ORDER BY hoc_item;


CREATE OR REPLACE VIEW employees AS
SELECT
	employee_id,
	max(project_job_code) project_job_code,
	count(DISTINCT project_job_code) distinct_project_job_code,
	sum(sum_of_time_hours) sum_of_time_hours
FROM Summary_of_Hours_by_HOC_Item
GROUP BY employee_id
ORDER BY employee_id;


CREATE VIEW employees_by_project_job_code AS
SELECT
	project_job_code,
	count(*) count,
	sum(sum_of_time_hours) computed_hours_worked,
	summary.hours_worked reported_hours_worked,
	summary.hourly_rate * sum(sum_of_time_hours)
		AS computed_monthly_total,
	summary.monthly_total reported_monthly_total
FROM employees
INNER JOIN Employee_Category_Summary summary
	ON summary.employee_category = employees.project_job_code
GROUP BY
	project_job_code,
	summary.hours_worked,
	summary.hourly_rate,
	summary.monthly_total
ORDER BY count DESC;


----------------------------------------------------------------
----------------------------------------------------------------
--
-- Cargar los datos
--

COPY Summary_of_Hours_by_HOC_Item_csv
FROM '/datos/2021-05/Summary_of_Hours_by_HOC_Item.csv'
CSV ENCODING 'UTF-8' HEADER NULL '';
ANALYZE VERBOSE Summary_of_Hours_by_HOC_Item_csv;

COPY Summary_of_Hours_by_HOC_Item_previous_months_csv
FROM '/datos/2021-05/Summary_of_Hours_by_HOC_Item_previous_months.csv'
CSV ENCODING 'UTF-8' HEADER NULL '';
ANALYZE VERBOSE Summary_of_Hours_by_HOC_Item_previous_months_csv;

COPY Employee_Category_Summary
FROM '/datos/2021-05/Employee_Category_Summary.csv'
CSV ENCODING 'UTF-8' HEADER NULL '';
ANALYZE VERBOSE Employee_Category_Summary;

REFRESH MATERIALIZED VIEW hoc_item_annex_2_definition;
ANALYZE VERBOSE hoc_item_annex_2_definition;

REFRESH MATERIALIZED VIEW Summary_of_Hours_by_HOC_Item;
ANALYZE VERBOSE Summary_of_Hours_by_HOC_Item;
