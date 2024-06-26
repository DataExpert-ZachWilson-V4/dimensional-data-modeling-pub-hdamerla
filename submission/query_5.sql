--query_5
/*incremental" query that can populate a single year's worth of the actors_history_scd*/

INSERT INTO hdamerla.actors_history_scd --CTE to get data from given and next year
WITH last_year_scd AS (
  SELECT * FROM hdamerla.actors_history_scd
  WHERE current_year = 2021
),

  current_year_scd AS (
  SELECT * FROM hdamerla.actors
  WHERE current_year = 2022
),

  combined AS (
SELECT 
  COALESCE(ls.actor, cs.actor) as actor,
  COALESCE(ls.actor_id, cs.actor_id) as actor_id,
  COALESCE(ls.start_date, cs.current_year) as start_date,
  COALESCE(ls.end_date, cs.current_year) as end_date,
  ls.is_active as is_active_last_year,
  cs.is_active as is_active_this_year,
  ls.quality_class AS quality_class_last_year,
  cs.quality_class AS quality_class_this_year,
 CASE 
    WHEN ls.is_active <> cs.is_active OR ls.quality_class <> cs.quality_class THEN 1
    WHEN ls.is_active = cs.is_active AND ls.quality_class = cs.quality_class THEN 0
END AS did_change,
  2021 AS current_year,
  ls.quality_class
FROM last_year_scd ls
FULL OUTER JOIN current_year_scd cs
ON ls.actor = cs.actor AND
ls.end_date + 1 = cs.current_year
),
changes AS (
SELECT
  actor,
  actor_id,
  current_year,
  quality_class,
  CASE 
    WHEN did_change = 0 THEN       
         ARRAY[CAST(ROW(quality_class_last_year, is_active_last_year, start_date, end_date+1) AS ROW(quality_class VARCHAR, is_active BOOLEAN, start_date INTEGER, end_date INTEGER))]
    WHEN did_change = 1 THEN
    ARRAY[CAST(ROW(quality_class_last_year, is_active_last_year, start_date, end_date) AS ROW(quality_class VARCHAR, is_active BOOLEAN, start_date INTEGER, end_date INTEGER)),
      CAST(ROW(quality_class_this_year, is_active_this_year, current_year , current_year) AS ROW(quality_class VARCHAR, is_active BOOLEAN, start_date INTEGER, end_date INTEGER))
      ]
      WHEN did_change is NULL THEN
        ARRAY[CAST(ROW(
        COALESCE(quality_class_last_year, quality_class_this_year), COALESCE(is_active_last_year, is_active_this_year), start_date, end_date) AS ROW(quality_class VARCHAR, is_active BOOLEAN, start_date INTEGER, end_date INTEGER))]
        end as change_array
        from combined
)

SELECT
  actor,
  actor_id,
  arr.quality_class,
  arr.is_active,
  arr.start_date,
  arr.end_date,
 current_year
FROM changes
CROSS JOIN UNNEST(change_array) as arr
