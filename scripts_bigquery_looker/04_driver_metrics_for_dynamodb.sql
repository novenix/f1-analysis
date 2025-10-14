-- ==============================================================================
-- OBJETIVO 4: MÉTRICAS DE PILOTO PARA CAPA DE SERVICIO (DynamoDB)
-- ==============================================================================
-- Descripción: Calcular métricas complejas y consolidadas de cada piloto
--              para ser "productizadas" y servidas desde DynamoDB.
--
-- Propósito: Alimentar el endpoint /api/driver/{driver_id}/profile
--            con métricas pre-calculadas de alto valor.
--
-- Métricas clave:
--   1. tyreManagementIndex: Habilidad para gestionar desgaste de neumáticos
--   2. consistencyScore: Consistencia de tiempos de vuelta
--   3. sectorPerformanceProfile: Rendimiento por tipo de sector
--
-- Proceso ETL: Estas queries se ejecutan periódicamente y sus resultados
--              se cargan a DynamoDB para servicio de baja latencia.
-- ==============================================================================

-- ==============================================================================
-- QUERY 4.1: Tyre Management Index (Gestión de Neumáticos)
-- ==============================================================================
-- Propósito: Calcular un score (1-10) que mide la habilidad del piloto
--            para mantener el rendimiento con neumáticos desgastados.
-- ==============================================================================

WITH driver_stint_performance AS (
  SELECT
    Driver,
    Year,
    EventName,
    Stint,
    Compound,
    COUNT(*) as stint_laps,
    MAX(TyreLife) as max_tyre_life,
    MIN(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) as best_lap_seconds,
    MAX(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) as worst_lap_seconds,
    AVG(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) as avg_lap_seconds,
    CORR(TyreLife, TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) as degradation_correlation

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND LapTime IS NOT NULL
    AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag
    AND Compound IN ('SOFT', 'MEDIUM', 'HARD')
    AND TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180

  GROUP BY Driver, Year, EventName, Stint, Compound
  HAVING COUNT(*) >= 10  -- Stints de al menos 10 vueltas
),

grid_average_degradation AS (
  SELECT
    Year,
    EventName,
    Compound,
    AVG(degradation_correlation) as grid_avg_degradation
  FROM driver_stint_performance
  GROUP BY Year, EventName, Compound
),

driver_tyre_scores AS (
  SELECT
    dsp.Driver,
    dsp.Year,
    AVG(dsp.degradation_correlation) as avg_degradation_corr,
    AVG(dsp.degradation_correlation - gad.grid_avg_degradation) as degradation_vs_grid,
    AVG(dsp.max_tyre_life) as avg_stint_duration,
    COUNTIF(dsp.max_tyre_life >= 20) as long_stint_count,
    COUNT(*) as total_stints
  FROM driver_stint_performance dsp
  LEFT JOIN grid_average_degradation gad
    ON dsp.Year = gad.Year AND dsp.EventName = gad.EventName AND dsp.Compound = gad.Compound
  GROUP BY dsp.Driver, dsp.Year
)

SELECT
  Driver,
  Year,
  ROUND(avg_degradation_corr, 4) as avg_degradation_correlation,
  ROUND(degradation_vs_grid, 4) as degradation_vs_grid_avg,
  ROUND(avg_stint_duration, 1) as avg_stint_duration_laps,
  long_stint_count,
  total_stints,
  ROUND(
    10 - (
      LEAST(GREATEST((degradation_vs_grid + 0.2) / 0.4, 0), 1) * 5 +
      LEAST(avg_stint_duration / 25, 1) * 3 +
      LEAST(long_stint_count / 10.0, 1) * 2
    ), 2
  ) as tyre_management_index
FROM driver_tyre_scores
ORDER BY Driver, Year DESC;


-- ==============================================================================
-- QUERY 4.2: Consistency Score (Consistencia de Tiempos)
-- ==============================================================================
-- Propósito: Medir qué tan consistentes son los tiempos de vuelta del piloto
--            durante stints largos.
-- ==============================================================================

WITH driver_consistency_raw AS (
  SELECT
    Driver, Year, EventName, Stint, Team,
    COUNT(*) as stint_laps,
    AVG(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) as avg_lap_seconds,
    STDDEV(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) as lap_time_std_dev,
    STDDEV(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) / NULLIF(AVG(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)), 0) as coefficient_of_variation
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND LapTime IS NOT NULL
    AND TrackStatus < 4
    AND TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
  GROUP BY Driver, Year, EventName, Stint, Team
  HAVING COUNT(*) >= 10
),

grid_consistency_benchmark AS (
  SELECT
    Year, EventName,
    AVG(coefficient_of_variation) as grid_avg_cov
  FROM driver_consistency_raw
  GROUP BY Year, EventName
),

driver_consistency_scores AS (
  SELECT
    dcr.Driver, dcr.Year,
    AVG(dcr.lap_time_std_dev) as avg_std_dev,
    AVG(dcr.coefficient_of_variation) as avg_cov,
    AVG(dcr.coefficient_of_variation - gcb.grid_avg_cov) as cov_vs_grid,
    COUNTIF(dcr.coefficient_of_variation < 0.02) as very_consistent_stints,
    COUNT(*) as total_stints
  FROM driver_consistency_raw dcr
  LEFT JOIN grid_consistency_benchmark gcb ON dcr.Year = gcb.Year AND dcr.EventName = gcb.EventName
  GROUP BY dcr.Driver, dcr.Year
)

SELECT
  Driver, Year,
  ROUND(avg_std_dev, 3) as avg_lap_time_std_dev_seconds,
  ROUND(avg_cov, 5) as avg_coefficient_of_variation,
  ROUND(cov_vs_grid, 5) as cov_vs_grid_avg,
  very_consistent_stints,
  total_stints,
  ROUND(
    10 * (
      (1 - LEAST(GREATEST((avg_cov - 0.01) / 0.04, 0), 1)) * 0.5 +
      CASE WHEN cov_vs_grid < 0 THEN 0.3 ELSE 0 END +
      LEAST(very_consistent_stints / NULLIF(total_stints, 0), 1) * 0.2
    ), 2
  ) as consistency_score
FROM driver_consistency_scores
ORDER BY Driver, Year DESC;


-- ==============================================================================
-- QUERY 4.3: Sector Performance Profile (Perfil por Tipo de Sector)
-- ==============================================================================
-- Propósito: Clasificar el rendimiento del piloto en diferentes tipos de sectores
--            (alta velocidad, técnico, baja velocidad).
-- ==============================================================================

WITH sector_classification AS (
  SELECT
    EventName, Year,
    CASE
      WHEN AVG(Sector1_Speed_Avg) >= 200 THEN 'High Speed'
      WHEN AVG(Sector1_Speed_Avg) >= 150 THEN 'Medium Speed'
      ELSE 'Low Speed'
    END as s1_type,
    CASE
      WHEN AVG(Sector2_Speed_Avg) >= 200 THEN 'High Speed'
      WHEN AVG(Sector2_Speed_Avg) >= 150 THEN 'Medium Speed'
      ELSE 'Low Speed'
    END as s2_type,
    CASE
      WHEN AVG(Sector3_Speed_Avg) >= 200 THEN 'High Speed'
      WHEN AVG(Sector3_Speed_Avg) >= 150 THEN 'Medium Speed'
      ELSE 'Low Speed'
    END as s3_type
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND TrackStatus < 4
  GROUP BY EventName, Year
),

driver_sector_performance AS (
  SELECT l.Driver, l.Year, l.EventName, sc.s1_type as sector_type, AVG(l.Sector1_Speed_Avg) as avg_speed
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN sector_classification sc ON l.EventName = sc.EventName AND l.Year = sc.Year
  WHERE l.EventDate >= '2021-01-01' AND l.SessionName = 'Race' AND l.Deleted = FALSE AND l.TrackStatus < 4 AND l.Sector1_Speed_Avg IS NOT NULL
  GROUP BY 1, 2, 3, 4
  UNION ALL
  SELECT l.Driver, l.Year, l.EventName, sc.s2_type as sector_type, AVG(l.Sector2_Speed_Avg) as avg_speed
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN sector_classification sc ON l.EventName = sc.EventName AND l.Year = sc.Year
  WHERE l.EventDate >= '2021-01-01' AND l.SessionName = 'Race' AND l.Deleted = FALSE AND l.TrackStatus < 4 AND l.Sector2_Speed_Avg IS NOT NULL
  GROUP BY 1, 2, 3, 4
  UNION ALL
  SELECT l.Driver, l.Year, l.EventName, sc.s3_type as sector_type, AVG(l.Sector3_Speed_Avg) as avg_speed
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN sector_classification sc ON l.EventName = sc.EventName AND l.Year = sc.Year
  WHERE l.EventDate >= '2021-01-01' AND l.SessionName = 'Race' AND l.Deleted = FALSE AND l.TrackStatus < 4 AND l.Sector3_Speed_Avg IS NOT NULL
  GROUP BY 1, 2, 3, 4
),

grid_sector_benchmarks AS (
  SELECT
    Year, EventName, sector_type,
    AVG(avg_speed) as grid_avg_speed,
    STDDEV(avg_speed) as grid_std_dev
  FROM driver_sector_performance
  GROUP BY 1, 2, 3
),

driver_sector_vs_grid AS (
  SELECT
    dsp.Driver, dsp.Year, dsp.sector_type,
    AVG(dsp.avg_speed) as driver_avg_speed,
    AVG(gsb.grid_avg_speed) as grid_avg_speed,
    AVG((dsp.avg_speed - gsb.grid_avg_speed) / NULLIF(gsb.grid_std_dev, 0)) as z_score
  FROM driver_sector_performance dsp
  JOIN grid_sector_benchmarks gsb ON dsp.Year = gsb.Year AND dsp.EventName = gsb.EventName AND dsp.sector_type = gsb.sector_type
  GROUP BY 1, 2, 3
)

SELECT
  Driver, Year, sector_type,
  ROUND(driver_avg_speed, 1) as avg_speed_kmh,
  ROUND(grid_avg_speed, 1) as grid_avg_speed_kmh,
  ROUND(z_score, 3) as performance_z_score,
  CASE
    WHEN z_score >= 1.0 THEN 'Elite'
    WHEN z_score >= 0.3 THEN 'Above Average'
    WHEN z_score >= -0.3 THEN 'Average'
    ELSE 'Below Average'
  END as performance_rating
FROM driver_sector_vs_grid
ORDER BY Driver, Year DESC, sector_type;


-- ==============================================================================
-- QUERY 4.4: Perfil Consolidado de Piloto (Para DynamoDB)
-- ==============================================================================
-- Propósito: Vista final que combina todas las métricas en un solo perfil.
--            Esta query genera el JSON que se cargará a DynamoDB.
-- ==============================================================================

WITH tyre_management AS (
  WITH stint_perf AS (
    SELECT
      Driver, Year,
      CORR(TyreLife, TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) as deg_corr
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE EventDate >= '2021-01-01' AND SessionName = 'Race' AND Deleted = FALSE AND LapTime IS NOT NULL AND TrackStatus < 4 AND Compound IN ('SOFT', 'MEDIUM', 'HARD') AND TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
    GROUP BY Driver, Year, EventName, Stint, Compound
    HAVING COUNT(*) >= 10
  )
  SELECT
    Driver, Year,
    ROUND(10 - (AVG(deg_corr) * 10 + 5), 2) as tyre_mgmt_index
  FROM stint_perf
  GROUP BY Driver, Year
),

consistency AS (
  WITH driver_cov AS (
    SELECT
      Driver, Year,
      STDDEV(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) / NULLIF(AVG(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)), 0) as cov
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE EventDate >= '2021-01-01' AND SessionName = 'Race' AND Deleted = FALSE AND LapTime IS NOT NULL AND TrackStatus < 4 AND TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
    GROUP BY Driver, Year, EventName, Stint
    HAVING COUNT(*) >= 10
  )
  SELECT
    Driver, Year,
    ROUND(10 * (1 - LEAST(AVG(cov) / 0.05, 1)), 2) as consistency_score
  FROM driver_cov
  GROUP BY Driver, Year
),

sector_profile AS (
  -- Reutiliza la lógica completa de la Query 4.3 para obtener los ratings finales
  WITH sector_classification AS (
  SELECT
    EventName, Year,
    CASE WHEN AVG(Sector1_Speed_Avg) >= 200 THEN 'High Speed' WHEN AVG(Sector1_Speed_Avg) >= 150 THEN 'Medium Speed' ELSE 'Low Speed' END as s1_type,
    CASE WHEN AVG(Sector2_Speed_Avg) >= 200 THEN 'High Speed' WHEN AVG(Sector2_Speed_Avg) >= 150 THEN 'Medium Speed' ELSE 'Low Speed' END as s2_type,
    CASE WHEN AVG(Sector3_Speed_Avg) >= 200 THEN 'High Speed' WHEN AVG(Sector3_Speed_Avg) >= 150 THEN 'Medium Speed' ELSE 'Low Speed' END as s3_type
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
  WHERE EventDate >= '2021-01-01' AND SessionName = 'Race' AND Deleted = FALSE AND TrackStatus < 4
  GROUP BY EventName, Year
  ),
  driver_sector_performance AS (
    SELECT l.Driver, l.Year, sc.s1_type as sector_type, AVG(l.Sector1_Speed_Avg) as avg_speed FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l JOIN sector_classification sc ON l.EventName = sc.EventName AND l.Year = sc.Year WHERE l.EventDate >= '2021-01-01' AND l.SessionName = 'Race' AND l.Deleted = FALSE AND l.TrackStatus < 4 AND l.Sector1_Speed_Avg IS NOT NULL GROUP BY 1, 2, 3
    UNION ALL
    SELECT l.Driver, l.Year, sc.s2_type as sector_type, AVG(l.Sector2_Speed_Avg) as avg_speed FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l JOIN sector_classification sc ON l.EventName = sc.EventName AND l.Year = sc.Year WHERE l.EventDate >= '2021-01-01' AND l.SessionName = 'Race' AND l.Deleted = FALSE AND l.TrackStatus < 4 AND l.Sector2_Speed_Avg IS NOT NULL GROUP BY 1, 2, 3
    UNION ALL
    SELECT l.Driver, l.Year, sc.s3_type as sector_type, AVG(l.Sector3_Speed_Avg) as avg_speed FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l JOIN sector_classification sc ON l.EventName = sc.EventName AND l.Year = sc.Year WHERE l.EventDate >= '2021-01-01' AND l.SessionName = 'Race' AND l.Deleted = FALSE AND l.TrackStatus < 4 AND l.Sector3_Speed_Avg IS NOT NULL GROUP BY 1, 2, 3
  ),
  grid_sector_benchmarks AS (
    SELECT Year, sector_type, AVG(avg_speed) as grid_avg_speed, STDDEV(avg_speed) as grid_std_dev FROM driver_sector_performance GROUP BY 1, 2
  ),
  driver_sector_vs_grid AS (
    SELECT dsp.Driver, dsp.Year, dsp.sector_type, AVG((dsp.avg_speed - gsb.grid_avg_speed) / NULLIF(gsb.grid_std_dev, 0)) as z_score
    FROM driver_sector_performance dsp JOIN grid_sector_benchmarks gsb ON dsp.Year = gsb.Year AND dsp.sector_type = gsb.sector_type
    GROUP BY 1, 2, 3
  )
  SELECT
    Driver, Year,
    -- Crear un struct con los perfiles por tipo de sector
    STRUCT(
      MAX(CASE WHEN sector_type = 'High Speed' THEN CASE WHEN z_score >= 1.0 THEN 'Elite' WHEN z_score >= 0.3 THEN 'Above Average' WHEN z_score >= -0.3 THEN 'Average' ELSE 'Below Average' END END) AS high_speed,
      MAX(CASE WHEN sector_type = 'Medium Speed' THEN CASE WHEN z_score >= 1.0 THEN 'Elite' WHEN z_score >= 0.3 THEN 'Above Average' WHEN z_score >= -0.3 THEN 'Average' ELSE 'Below Average' END END) AS medium_speed,
      MAX(CASE WHEN sector_type = 'Low Speed' THEN CASE WHEN z_score >= 1.0 THEN 'Elite' WHEN z_score >= 0.3 THEN 'Above Average' WHEN z_score >= -0.3 THEN 'Average' ELSE 'Below Average' END END) AS low_speed
    ) AS sector_performance_profile
  FROM driver_sector_vs_grid
  GROUP BY Driver, Year
),

race_results_summary AS (
  SELECT
    r.Abbreviation as Driver, r.Year,
    COUNT(*) as races_entered,
    COUNTIF(CAST(r.Position AS INT64) = 1) as wins,
    COUNTIF(CAST(r.Position AS INT64) <= 3) as podiums,
    SUM(r.Points) as total_points,
    AVG(CAST(r.Position AS INT64)) as avg_finish_position
  FROM `topicos-bases-datos.f1_data_warehouse.results` r
  WHERE r.Year >= 2021 AND r.SessionName = 'Race' AND r.Position IS NOT NULL
  GROUP BY 1, 2
)

-- Query final: Perfil completo del piloto
SELECT
  COALESCE(tm.Driver, c.Driver, sp.Driver, rr.Driver) as driver_code,
  COALESCE(tm.Year, c.Year, sp.Year, rr.Year) as year,
  COALESCE(tm.tyre_mgmt_index, 5.0) as tyre_management_index,
  COALESCE(c.consistency_score, 5.0) as consistency_score,
  sp.sector_performance_profile,
  rr.races_entered,
  rr.wins,
  rr.podiums,
  ROUND(rr.total_points, 1) as total_points,
  ROUND(rr.avg_finish_position, 2) as avg_finish_position
FROM tyre_management tm
FULL OUTER JOIN consistency c ON tm.Driver = c.Driver AND tm.Year = c.Year
FULL OUTER JOIN sector_profile sp ON COALESCE(tm.Driver, c.Driver) = sp.Driver AND COALESCE(tm.Year, c.Year) = sp.Year
FULL OUTER JOIN race_results_summary rr ON COALESCE(tm.Driver, c.Driver, sp.Driver) = rr.Driver AND COALESCE(tm.Year, c.Year, sp.Year) = rr.Year
WHERE COALESCE(tm.Driver, c.Driver, sp.Driver, rr.Driver) IS NOT NULL
ORDER BY year DESC, driver_code;