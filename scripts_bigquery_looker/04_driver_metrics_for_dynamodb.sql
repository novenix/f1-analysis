-- ==============================================================================
-- OBJETIVO 4: MÉTRICAS DE PILOTO PARA CAPA DE SERVICIO (DynamoDB)
-- ==============================================================================
-- Descripción: Calcular métricas complejas y consolidadas de cada piloto
--              para ser "productizadas" y servidas desde DynamoDB
--
-- Propósito: Alimentar el endpoint /api/driver/{driver_id}/profile
--            con métricas pre-calculadas de alto valor
--
-- Métricas clave:
--   1. tyreManagementIndex: Habilidad para gestionar desgaste de neumáticos
--   2. consistencyScore: Consistencia de tiempos de vuelta
--   3. sectorPerformanceProfile: Rendimiento por tipo de sector
--
-- Proceso ETL: Estas queries se ejecutan periódicamente y sus resultados
--              se cargan a DynamoDB para servicio de baja latencia
-- ==============================================================================

-- ==============================================================================
-- QUERY 4.1: Tyre Management Index (Gestión de Neumáticos)
-- ==============================================================================
-- Propósito: Calcular un score (1-10) que mide la habilidad del piloto
--            para mantener el rendimiento con neumáticos desgastados
--
-- Metodología:
--   - Comparar degradación del piloto vs promedio del grid
--   - Analizar consistencia de tiempos en stints largos
--   - Considerar todos los compuestos
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

    -- Calcular degradación
    MIN(
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as best_lap_seconds,

    MAX(
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as worst_lap_seconds,

    AVG(
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as avg_lap_seconds,

    -- Correlación TyreLife vs LapTime (degradación lineal)
    CORR(
      TyreLife,
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as degradation_correlation

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND LapTime IS NOT NULL
    AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag
    AND Compound IN ('SOFT', 'MEDIUM', 'HARD')
    AND (
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) BETWEEN 60 AND 180

  GROUP BY Driver, Year, EventName, Stint, Compound
  HAVING COUNT(*) >= 10  -- Stints de al menos 10 vueltas
),

grid_average_degradation AS (
  -- Calcular promedio del grid para normalizar
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

    -- Degradación promedio del piloto
    AVG(dsp.degradation_correlation) as avg_degradation_corr,

    -- Comparado con el grid
    AVG(dsp.degradation_correlation - gad.grid_avg_degradation) as degradation_vs_grid,

    -- Duración promedio de stint (indicador de gestión)
    AVG(dsp.max_tyre_life) as avg_stint_duration,

    -- Número de stints largos exitosos
    COUNTIF(dsp.max_tyre_life >= 20) as long_stint_count,

    COUNT(*) as total_stints

  FROM driver_stint_performance dsp
  LEFT JOIN grid_average_degradation gad
    ON dsp.Year = gad.Year
    AND dsp.EventName = gad.EventName
    AND dsp.Compound = gad.Compound

  GROUP BY dsp.Driver, dsp.Year
)

SELECT
  Driver,
  Year,

  -- Raw metrics
  ROUND(avg_degradation_corr, 4) as avg_degradation_correlation,
  ROUND(degradation_vs_grid, 4) as degradation_vs_grid_avg,
  ROUND(avg_stint_duration, 1) as avg_stint_duration_laps,
  long_stint_count,
  total_stints,

  -- TYRE MANAGEMENT INDEX (1-10)
  -- Menor degradación = mejor score
  -- Normalizar: score alto = buena gestión
  ROUND(
    10 - (
      -- Normalizar degradation_vs_grid a escala 0-10
      -- Rango típico: -0.2 a +0.2
      LEAST(GREATEST((degradation_vs_grid + 0.2) / 0.4, 0), 1) * 5 +
      -- Penalizar stints cortos
      LEAST(avg_stint_duration / 25, 1) * 3 +
      -- Bonificar stints largos exitosos
      LEAST(long_stint_count / 10.0, 1) * 2
    ),
    2
  ) as tyre_management_index

FROM driver_tyre_scores

ORDER BY Driver, Year DESC;


-- ==============================================================================
-- QUERY 4.2: Consistency Score (Consistencia de Tiempos)
-- ==============================================================================
-- Propósito: Medir qué tan consistentes son los tiempos de vuelta del piloto
--            durante stints largos (importante para estrategia)
--
-- Metodología:
--   - Calcular desviación estándar de tiempos por stint
--   - Comparar con el promedio del grid
--   - Score alto = muy consistente (baja variabilidad)
-- ==============================================================================

WITH driver_consistency_raw AS (
  SELECT
    Driver,
    Year,
    EventName,
    Stint,
    Team,

    COUNT(*) as stint_laps,

    -- Estadísticas de tiempo
    AVG(
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as avg_lap_seconds,

    STDDEV(
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as lap_time_std_dev,

    -- Coeficiente de variación (normalizado)
    STDDEV(
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) / AVG(
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as coefficient_of_variation

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND LapTime IS NOT NULL
    AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag
    AND (
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) BETWEEN 60 AND 180

  GROUP BY Driver, Year, EventName, Stint, Team
  HAVING COUNT(*) >= 10
),

grid_consistency_benchmark AS (
  SELECT
    Year,
    EventName,

    AVG(coefficient_of_variation) as grid_avg_cov

  FROM driver_consistency_raw

  GROUP BY Year, EventName
),

driver_consistency_scores AS (
  SELECT
    dcr.Driver,
    dcr.Year,

    -- Métricas raw
    AVG(dcr.lap_time_std_dev) as avg_std_dev,
    AVG(dcr.coefficient_of_variation) as avg_cov,

    -- Comparado con el grid
    AVG(dcr.coefficient_of_variation - gcb.grid_avg_cov) as cov_vs_grid,

    -- Conteo de stints consistentes (COV < 0.02 = muy consistente)
    COUNTIF(dcr.coefficient_of_variation < 0.02) as very_consistent_stints,
    COUNT(*) as total_stints

  FROM driver_consistency_raw dcr
  LEFT JOIN grid_consistency_benchmark gcb
    ON dcr.Year = gcb.Year
    AND dcr.EventName = gcb.EventName

  GROUP BY dcr.Driver, dcr.Year
)

SELECT
  Driver,
  Year,

  -- Raw metrics
  ROUND(avg_std_dev, 3) as avg_lap_time_std_dev_seconds,
  ROUND(avg_cov, 5) as avg_coefficient_of_variation,
  ROUND(cov_vs_grid, 5) as cov_vs_grid_avg,
  very_consistent_stints,
  total_stints,

  -- CONSISTENCY SCORE (1-10)
  -- Menor COV = mejor score
  ROUND(
    10 * (
      -- Normalizar COV a escala 0-1 (rango típico: 0.01 a 0.05)
      (1 - LEAST(GREATEST((avg_cov - 0.01) / 0.04, 0), 1)) * 0.5 +
      -- Bonificar si está por debajo del promedio del grid
      CASE WHEN cov_vs_grid < 0 THEN 0.3 ELSE 0 END +
      -- Bonificar stints muy consistentes
      LEAST(very_consistent_stints / total_stints, 1) * 0.2
    ),
    2
  ) as consistency_score

FROM driver_consistency_scores

ORDER BY Driver, Year DESC;


-- ==============================================================================
-- QUERY 4.3: Sector Performance Profile (Perfil por Tipo de Sector)
-- ==============================================================================
-- Propósito: Clasificar el rendimiento del piloto en diferentes tipos de sectores
--            (alta velocidad, técnico, baja velocidad)
--
-- Metodología:
--   1. Clasificar sectores por velocidad promedio
--   2. Comparar performance del piloto vs grid en cada tipo
--   3. Etiquetar como: Elite, Above Average, Average, Below Average
-- ==============================================================================

WITH sector_classification AS (
  -- Clasificar cada sector de cada circuito
  SELECT
    EventName,
    Year,

    -- Sector 1
    AVG(Sector1_Speed_Avg) as s1_avg_speed,
    CASE
      WHEN AVG(Sector1_Speed_Avg) >= 200 THEN 'High Speed'
      WHEN AVG(Sector1_Speed_Avg) >= 150 THEN 'Medium Speed'
      ELSE 'Low Speed'
    END as s1_type,

    -- Sector 2
    AVG(Sector2_Speed_Avg) as s2_avg_speed,
    CASE
      WHEN AVG(Sector2_Speed_Avg) >= 200 THEN 'High Speed'
      WHEN AVG(Sector2_Speed_Avg) >= 150 THEN 'Medium Speed'
      ELSE 'Low Speed'
    END as s2_type,

    -- Sector 3
    AVG(Sector3_Speed_Avg) as s3_avg_speed,
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
    AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag

  GROUP BY EventName, Year
),

driver_sector_performance AS (
  SELECT
    l.Driver,
    l.Year,
    l.EventName,
    sc.s1_type as sector_type,

    -- Performance en Sector 1
    AVG(l.Sector1_Speed_Avg) as avg_speed

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN sector_classification sc
    ON l.EventName = sc.EventName
    AND l.Year = sc.Year

  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.TrackStatus IN ('1', '124')
    AND l.Sector1_Speed_Avg IS NOT NULL

  GROUP BY l.Driver, l.Year, l.EventName, sector_type

  UNION ALL

  -- Sector 2
  SELECT
    l.Driver,
    l.Year,
    l.EventName,
    sc.s2_type as sector_type,
    AVG(l.Sector2_Speed_Avg) as avg_speed

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN sector_classification sc
    ON l.EventName = sc.EventName
    AND l.Year = sc.Year

  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.TrackStatus IN ('1', '124')
    AND l.Sector2_Speed_Avg IS NOT NULL

  GROUP BY l.Driver, l.Year, l.EventName, sector_type

  UNION ALL

  -- Sector 3
  SELECT
    l.Driver,
    l.Year,
    l.EventName,
    sc.s3_type as sector_type,
    AVG(l.Sector3_Speed_Avg) as avg_speed

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN sector_classification sc
    ON l.EventName = sc.EventName
    AND l.Year = sc.Year

  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.TrackStatus IN ('1', '124')
    AND l.Sector3_Speed_Avg IS NOT NULL

  GROUP BY l.Driver, l.Year, l.EventName, sector_type
),

grid_sector_benchmarks AS (
  SELECT
    Year,
    EventName,
    sector_type,

    AVG(avg_speed) as grid_avg_speed,
    STDDEV(avg_speed) as grid_std_dev

  FROM driver_sector_performance

  GROUP BY Year, EventName, sector_type
),

driver_sector_vs_grid AS (
  SELECT
    dsp.Driver,
    dsp.Year,
    dsp.sector_type,

    AVG(dsp.avg_speed) as driver_avg_speed,
    AVG(gsb.grid_avg_speed) as grid_avg_speed,

    -- Z-score (cuántas desviaciones estándar sobre/bajo el promedio)
    AVG((dsp.avg_speed - gsb.grid_avg_speed) / NULLIF(gsb.grid_std_dev, 0)) as z_score

  FROM driver_sector_performance dsp
  JOIN grid_sector_benchmarks gsb
    ON dsp.Year = gsb.Year
    AND dsp.EventName = gsb.EventName
    AND dsp.sector_type = gsb.sector_type

  GROUP BY dsp.Driver, dsp.Year, dsp.sector_type
)

SELECT
  Driver,
  Year,
  sector_type,

  ROUND(driver_avg_speed, 1) as avg_speed_kmh,
  ROUND(grid_avg_speed, 1) as grid_avg_speed_kmh,
  ROUND(z_score, 3) as performance_z_score,

  -- PERFORMANCE LABEL
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
-- Propósito: Vista final que combina todas las métricas en un solo perfil
--            Esta query genera el JSON que se cargará a DynamoDB
--
-- Output: Un registro por piloto-año con todas las métricas
-- ==============================================================================

WITH tyre_management AS (
  -- Reutilizar lógica de Query 4.1 (simplificada)
  WITH stint_perf AS (
    SELECT
      Driver, Year,
      CORR(
        TyreLife,
        CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
        CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
        CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
      ) as deg_corr,
      MAX(TyreLife) as max_life
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE EventDate >= '2021-01-01' AND SessionName = 'Race'
      AND Deleted = FALSE AND LapTime IS NOT NULL
      AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag
      AND Compound IN ('SOFT', 'MEDIUM', 'HARD')
      AND (
        CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
        CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
        CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
      ) BETWEEN 60 AND 180
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
  -- Reutilizar lógica de Query 4.2 (simplificada)
  WITH driver_cov AS (
    SELECT
      Driver, Year,
      STDDEV(
        CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
        CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
        CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
      ) / AVG(
        CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
        CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
        CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
      ) as cov
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE EventDate >= '2021-01-01' AND SessionName = 'Race'
      AND Deleted = FALSE AND LapTime IS NOT NULL
      AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag
      AND (
        CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
        CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
        CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
      ) BETWEEN 60 AND 180
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
  -- Reutilizar lógica de Query 4.3 (simplificada)
  WITH sector_data AS (
    SELECT
      Driver, Year,
      CASE
        WHEN AVG(Sector1_Speed_Avg) >= 200 THEN 'High Speed'
        WHEN AVG(Sector1_Speed_Avg) >= 150 THEN 'Medium Speed'
        ELSE 'Low Speed'
      END as sector_type,
      AVG(Sector1_Speed_Avg) as avg_speed
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE EventDate >= '2021-01-01' AND SessionName = 'Race'
      AND Deleted = FALSE AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag
    GROUP BY Driver, Year, EventName
  )
  SELECT
    Driver, Year,
    MAX(CASE WHEN sector_type = 'High Speed' THEN avg_speed END) as high_speed_perf,
    MAX(CASE WHEN sector_type = 'Medium Speed' THEN avg_speed END) as medium_speed_perf,
    MAX(CASE WHEN sector_type = 'Low Speed' THEN avg_speed END) as low_speed_perf
  FROM sector_data
  GROUP BY Driver, Year
),

race_results_summary AS (
  SELECT
    r.Abbreviation as Driver,
    r.Year,

    -- Estadísticas de resultados
    COUNT(*) as races_entered,
    COUNTIF(CAST(r.Position AS INT64) = 1) as wins,
    COUNTIF(CAST(r.Position AS INT64) <= 3) as podiums,
    COUNTIF(CAST(r.Position AS INT64) <= 10) as points_finishes,
    SUM(r.Points) as total_points,

    -- Posición promedio
    AVG(CAST(r.Position AS INT64)) as avg_finish_position,

    -- Mejor resultado
    MIN(CAST(r.Position AS INT64)) as best_finish

  FROM `topicos-bases-datos.f1_data_warehouse.results` r

  WHERE
    r.Year >= 2021
    AND r.SessionName = 'Race'
    AND r.Position IS NOT NULL
    

  GROUP BY r.Abbreviation, r.Year
)

-- Query final: Perfil completo del piloto
SELECT
  COALESCE(tm.Driver, c.Driver, sp.Driver, rr.Driver) as driver_code,
  COALESCE(tm.Year, c.Year, sp.Year, rr.Year) as year,

  -- Core metrics
  COALESCE(tm.tyre_mgmt_index, 5.0) as tyre_management_index,
  COALESCE(c.consistency_score, 5.0) as consistency_score,

  -- Sector performance profile
  STRUCT(
    CASE
      WHEN sp.high_speed_perf >= 200 THEN 'Elite'
      WHEN sp.high_speed_perf >= 180 THEN 'Above Average'
      ELSE 'Average'
    END as high_speed_performance,

    CASE
      WHEN sp.medium_speed_perf >= 160 THEN 'Elite'
      WHEN sp.medium_speed_perf >= 140 THEN 'Above Average'
      ELSE 'Average'
    END as medium_speed_performance,

    CASE
      WHEN sp.low_speed_perf >= 140 THEN 'Elite'
      WHEN sp.low_speed_perf >= 120 THEN 'Above Average'
      ELSE 'Average'
    END as low_speed_performance
  ) as sector_performance_profile,

  -- Race statistics
  rr.races_entered,
  rr.wins,
  rr.podiums,
  rr.points_finishes,
  ROUND(rr.total_points, 1) as total_points,
  ROUND(rr.avg_finish_position, 2) as avg_finish_position,
  rr.best_finish

FROM tyre_management tm
FULL OUTER JOIN consistency c
  ON tm.Driver = c.Driver AND tm.Year = c.Year
FULL OUTER JOIN sector_profile sp
  ON COALESCE(tm.Driver, c.Driver) = sp.Driver
  AND COALESCE(tm.Year, c.Year) = sp.Year
FULL OUTER JOIN race_results_summary rr
  ON COALESCE(tm.Driver, c.Driver, sp.Driver) = rr.Driver
  AND COALESCE(tm.Year, c.Year, sp.Year) = rr.Year

WHERE COALESCE(tm.Driver, c.Driver, sp.Driver, rr.Driver) IS NOT NULL

ORDER BY year DESC, driver_code;


-- ==============================================================================
-- NOTAS DE USO PARA ETL A DYNAMODB
-- ==============================================================================
--
-- 1. QUERY 4.4 (Perfil Consolidado) es la principal para cargar a DynamoDB
--    - Ejecutar periódicamente (ej: después de cada carrera)
--    - Formato de salida: JSON por piloto
--    - Primary Key en DynamoDB: driver_code (Partition Key) + year (Sort Key)
--
-- 2. Estructura sugerida del item en DynamoDB:
--    {
--      "driver_code": "VER",
--      "year": 2024,
--      "tyre_management_index": 8.5,
--      "consistency_score": 9.2,
--      "sector_performance_profile": {
--        "high_speed_performance": "Elite",
--        "medium_speed_performance": "Above Average",
--        "low_speed_performance": "Elite"
--      },
--      "races_entered": 22,
--      "wins": 19,
--      "podiums": 21,
--      "total_points": 575.0,
--      "avg_finish_position": 1.23,
--      "best_finish": 1,
--      "last_updated": "2024-12-01T00:00:00Z"
--    }
--
-- 3. Script Python para cargar a DynamoDB:
--    - Ejecutar Query 4.4 en BigQuery
--    - Exportar resultados a JSON
--    - Batch write a DynamoDB
--
-- 4. API Endpoint (Lambda):
--    GET /api/driver/{driver_code}/profile?year=2024
--    - Lookup directo en DynamoDB (latencia < 10ms)
--    - Sin procesamiento adicional necesario
--
-- ==============================================================================
