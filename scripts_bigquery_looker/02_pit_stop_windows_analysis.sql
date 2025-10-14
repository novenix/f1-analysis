-- ==============================================================================
-- OBJETIVO 2: EVALUAR EL IMPACTO DE LAS VENTANAS DE PARADA EN PITS
-- ==============================================================================
-- Descripción: Analizar el timing óptimo de las paradas en pits y su impacto
--              en el resultado final de la carrera
--
-- Visualización objetivo: Tabla comparativa / Gráfico de barras
--   - Cohortes de estrategia (Parada Temprana, Óptima, Tardía)
--   - Métricas: Posición final promedio, tiempo total, adelantamientos
--
-- Optimización: Usa particionamiento por EventDate y clustering
-- ==============================================================================

-- ==============================================================================
-- QUERY 2.1: Identificar Primera Parada de cada Piloto
-- ==============================================================================
-- Propósito: Determinar en qué vuelta cada piloto hizo su primera parada
--            y clasificarlo en cohortes estratégicas
--
-- Para Looker: Vista base para análisis de estrategias
-- ==============================================================================

WITH pit_stops AS (
  SELECT
    EventName,
    EventDate,
    Year,
    Country,
    Driver,
    Team,

    -- Detectar paradas: cambio de Stint
    Stint,
    LapNumber,

    -- Primera vuelta de cada stint
    MIN(LapNumber) OVER (
      PARTITION BY EventName, Year, Driver, Stint
      ORDER BY LapNumber
    ) as stint_start_lap,

    -- Compuesto usado en el stint
    Compound,

    -- Vida del neumático
    TyreLife

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND Stint IS NOT NULL
),

first_pit_stop AS (
  SELECT
    EventName,
    EventDate,
    Year,
    Country,
    Driver,
    Team,

    -- Vuelta de la primera parada (inicio del Stint 2)
    MIN(CASE WHEN Stint = 2 THEN stint_start_lap END) as first_pit_lap,

    -- Compuesto del primer stint
    MAX(CASE WHEN Stint = 1 THEN Compound END) as stint1_compound,

    -- Compuesto del segundo stint
    MAX(CASE WHEN Stint = 2 THEN Compound END) as stint2_compound,

    -- Número total de paradas (stints - 1)
    MAX(Stint) - 1 as total_pit_stops,

    -- Total de stints
    MAX(Stint) as total_stints

  FROM pit_stops

  GROUP BY EventName, EventDate, Year, Country, Driver, Team
),

-- Obtener resultados finales
race_results AS (
  SELECT
    r.EventName,
    r.Year,
    r.Abbreviation as Driver,
    r.TeamName as Team,

    -- Posición final
    CAST(r.Position AS INT64) as final_position,

    -- Posición de salida
    CAST(r.GridPosition AS INT64) as grid_position,

    -- Posiciones ganadas/perdidas
    CAST(r.GridPosition AS INT64) - CAST(r.Position AS INT64) as positions_gained,

    -- Puntos obtenidos
    r.Points,

    -- Estado final
    r.Status,

    -- Tiempo total de carrera (convertir a segundos)
    CASE
      WHEN r.Time IS NOT NULL THEN
        CAST(SPLIT(r.Time, ':')[SAFE_OFFSET(0)] AS INT64) * 3600 +
        CAST(SPLIT(r.Time, ':')[SAFE_OFFSET(1)] AS INT64) * 60 +
        CAST(SPLIT(r.Time, ':')[SAFE_OFFSET(2)] AS FLOAT64)
      ELSE NULL
    END as race_time_seconds

  FROM `topicos-bases-datos.f1_data_warehouse.results` r

  WHERE
    r.Year >= 2021
    AND r.SessionName = 'Race'
    AND r.Position IS NOT NULL
),

-- Calcular estadísticas del circuito para clasificar cohortes
circuit_stats AS (
  SELECT
    EventName,
    Year,

    -- Estadísticas de cuando paran
    AVG(first_pit_lap) as avg_first_pit_lap,
    STDDEV(first_pit_lap) as stddev_first_pit_lap,
    MIN(first_pit_lap) as min_first_pit_lap,
    MAX(first_pit_lap) as max_first_pit_lap,

    -- Percentiles
    APPROX_QUANTILES(first_pit_lap, 3)[OFFSET(1)] as pit_lap_p33,
    APPROX_QUANTILES(first_pit_lap, 3)[OFFSET(2)] as pit_lap_p66

  FROM first_pit_stop
  WHERE first_pit_lap IS NOT NULL
  GROUP BY EventName, Year
)

-- Query principal: Unir todo y clasificar estrategias
SELECT
  ps.EventName,
  ps.Year,
  ps.Country,
  ps.Driver,
  ps.Team,

  -- Información de paradas
  ps.first_pit_lap,
  ps.total_pit_stops,
  ps.total_stints,
  ps.stint1_compound,
  ps.stint2_compound,

  -- Clasificar en cohortes estratégicas
  CASE
    WHEN ps.first_pit_lap IS NULL THEN 'No Pit Stop'
    WHEN ps.first_pit_lap < cs.pit_lap_p33 THEN 'Early Stop (Undercut)'
    WHEN ps.first_pit_lap <= cs.pit_lap_p66 THEN 'Optimal Window'
    ELSE 'Late Stop (Overcut)'
  END as strategy_cohort,

  -- Metadata del circuito
  cs.avg_first_pit_lap as circuit_avg_pit_lap,
  cs.pit_lap_p33,
  cs.pit_lap_p66,

  -- Resultados de carrera
  rr.grid_position,
  rr.final_position,
  rr.positions_gained,
  rr.Points,
  rr.Status,
  rr.race_time_seconds,

  -- Formatear tiempo de carrera
  CASE
    WHEN rr.race_time_seconds IS NOT NULL THEN
      CONCAT(
        CAST(CAST(rr.race_time_seconds / 3600 AS INT64) AS STRING), ':',
        LPAD(CAST(CAST((rr.race_time_seconds % 3600) / 60 AS INT64) AS STRING), 2, '0'), ':',
        FORMAT('%06.3f', MOD(rr.race_time_seconds, 60))
      )
    ELSE NULL
  END as race_time_formatted

FROM first_pit_stop ps
LEFT JOIN circuit_stats cs
  ON ps.EventName = cs.EventName
  AND ps.Year = cs.Year
LEFT JOIN race_results rr
  ON ps.EventName = rr.EventName
  AND ps.Year = rr.Year
  AND ps.Driver = rr.Driver

ORDER BY ps.Year DESC, ps.EventName, rr.final_position;


-- ==============================================================================
-- QUERY 2.2: Comparativa de Cohortes de Estrategia
-- ==============================================================================
-- Propósito: Comparar métricas de rendimiento entre diferentes cohortes
--            (Early, Optimal, Late)
--
-- Para Looker: Tabla comparativa o gráfico de barras
-- ==============================================================================

WITH strategy_data AS (
  -- Reutilizar lógica de Query 2.1 (simplificada)
  WITH pit_stops AS (
    SELECT
      EventName,
      EventDate,
      Year,
      Driver,
      Team,
      Stint,
      LapNumber,
      MIN(LapNumber) OVER (
        PARTITION BY EventName, Year, Driver, Stint
        ORDER BY LapNumber
      ) as stint_start_lap
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE
      EventDate >= '2021-01-01'
      AND SessionName = 'Race'
      AND Deleted = FALSE
      AND Stint IS NOT NULL
  ),
  first_pit AS (
    SELECT
      EventName, Year, Driver, Team,
      MIN(CASE WHEN Stint = 2 THEN stint_start_lap END) as first_pit_lap
    FROM pit_stops
    GROUP BY EventName, Year, Driver, Team
  ),
  circuit_stats AS (
    SELECT
      EventName, Year,
      APPROX_QUANTILES(first_pit_lap, 3)[OFFSET(1)] as p33,
      APPROX_QUANTILES(first_pit_lap, 3)[OFFSET(2)] as p66
    FROM first_pit
    WHERE first_pit_lap IS NOT NULL
    GROUP BY EventName, Year
  ),
  results AS (
    SELECT
      r.EventName, r.Year, r.Abbreviation as Driver,
      CAST(r.Position AS INT64) as final_position,
      CAST(r.GridPosition AS INT64) as grid_position,
      r.Points,
      r.Status
    FROM `topicos-bases-datos.f1_data_warehouse.results` r
    WHERE r.Year >= 2021 AND r.SessionName = 'Race'
      AND r.Position IS NOT NULL 
  )

  SELECT
    fp.EventName,
    fp.Year,
    fp.Driver,
    fp.Team,
    fp.first_pit_lap,

    CASE
      WHEN fp.first_pit_lap IS NULL THEN 'No Pit Stop'
      WHEN fp.first_pit_lap < cs.p33 THEN 'Early Stop'
      WHEN fp.first_pit_lap <= cs.p66 THEN 'Optimal Window'
      ELSE 'Late Stop'
    END as cohort,

    r.grid_position,
    r.final_position,
    r.grid_position - r.final_position as positions_gained,
    r.Points,
    r.Status

  FROM first_pit fp
  LEFT JOIN circuit_stats cs ON fp.EventName = cs.EventName AND fp.Year = cs.Year
  LEFT JOIN results r ON fp.EventName = r.EventName AND fp.Year = r.Year AND fp.Driver = r.Driver
)

SELECT
  Year,
  EventName,
  cohort,

  -- Tamaño de la cohorte
  COUNT(*) as drivers_count,

  -- Posición final promedio
  ROUND(AVG(final_position), 2) as avg_final_position,

  -- Posición de salida promedio
  ROUND(AVG(grid_position), 2) as avg_grid_position,

  -- Posiciones ganadas promedio
  ROUND(AVG(positions_gained), 2) as avg_positions_gained,

  -- Puntos promedio
  ROUND(AVG(Points), 2) as avg_points,

  -- Tasa de finalización (finished / total)
  ROUND(
    COUNTIF(Status = 'Finished') / COUNT(*) * 100,
    1
  ) as finish_rate_percent,

  -- Vuelta promedio de primera parada
  ROUND(AVG(first_pit_lap), 1) as avg_pit_lap

FROM strategy_data

WHERE cohort != 'No Pit Stop'  -- Excluir casos sin parada

GROUP BY Year, EventName, cohort

ORDER BY Year DESC, EventName,
  CASE cohort
    WHEN 'Early Stop' THEN 1
    WHEN 'Optimal Window' THEN 2
    WHEN 'Late Stop' THEN 3
  END;


-- ==============================================================================
-- QUERY 2.3: Análisis de Undercut vs Overcut
-- ==============================================================================
-- Propósito: Analizar qué estrategia (parar antes o después) es más efectiva
--            en cada circuito
--
-- Para Looker: Visualización de éxito por tipo de estrategia
-- ==============================================================================

WITH race_data AS (
  WITH pit_stops AS (
    SELECT
      EventName, EventDate, Year, Driver, Team, Stint, LapNumber,
      MIN(LapNumber) OVER (PARTITION BY EventName, Year, Driver, Stint) as stint_start
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE EventDate >= '2021-01-01' AND SessionName = 'Race'
      AND Deleted = FALSE AND Stint IS NOT NULL
  ),
  first_pit AS (
    SELECT
      EventName, Year, Driver, Team,
      MIN(CASE WHEN Stint = 2 THEN stint_start END) as first_pit_lap
    FROM pit_stops
    GROUP BY EventName, Year, Driver, Team
  ),
  results AS (
    SELECT
      r.EventName, r.Year, r.Abbreviation as Driver,
      CAST(r.GridPosition AS INT64) as grid,
      CAST(r.Position AS INT64) as final_pos
    FROM `topicos-bases-datos.f1_data_warehouse.results` r
    WHERE r.Year >= 2021 AND r.SessionName = 'Race'
  )

  SELECT
    fp.EventName,
    fp.Year,
    fp.first_pit_lap,
    r.grid,
    r.final_pos,
    r.grid - r.final_pos as gained,

    -- Clasificar como undercut o overcut basado en percentil 50
    CASE
      WHEN fp.first_pit_lap < PERCENTILE_CONT(fp.first_pit_lap, 0.5)
           OVER (PARTITION BY fp.EventName, fp.Year)
      THEN 'Undercut (Early)'
      ELSE 'Overcut (Late)'
    END as strategy_type

  FROM first_pit fp
  JOIN results r
    ON fp.EventName = r.EventName
    AND fp.Year = r.Year
    AND fp.Driver = r.Driver
  WHERE fp.first_pit_lap IS NOT NULL
)

SELECT
  Year,
  EventName,
  strategy_type,

  COUNT(*) as sample_size,

  -- Posiciones ganadas promedio
  ROUND(AVG(gained), 2) as avg_positions_gained,

  -- Tasa de éxito (ganar al menos 1 posición)
  ROUND(COUNTIF(gained > 0) / COUNT(*) * 100, 1) as success_rate_percent,

  -- Mejor caso
  MAX(gained) as max_positions_gained,

  -- Peor caso
  MIN(gained) as max_positions_lost

FROM race_data

GROUP BY Year, EventName, strategy_type

ORDER BY Year DESC, EventName, strategy_type;


-- ==============================================================================
-- QUERY 2.4: Impacto de Estrategias de 1 vs 2 Paradas
-- ==============================================================================
-- Propósito: Comparar rendimiento entre estrategias de 1 parada vs 2 paradas
--
-- Para Looker: Comparativa de estrategias multi-stop
-- ==============================================================================

WITH stint_counts AS (
  SELECT
    EventName,
    Year,
    Driver,
    Team,
    MAX(Stint) as total_stints,
    MAX(Stint) - 1 as total_stops

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND Stint IS NOT NULL

  GROUP BY EventName, Year, Driver, Team
),

results_with_strategy AS (
  SELECT
    sc.EventName,
    sc.Year,
    sc.Driver,
    sc.Team,
    sc.total_stops,

    CASE
      WHEN sc.total_stops = 0 THEN '0-Stop'
      WHEN sc.total_stops = 1 THEN '1-Stop'
      WHEN sc.total_stops = 2 THEN '2-Stop'
      ELSE '3+-Stop'
    END as stop_strategy,

    CAST(r.GridPosition AS INT64) as grid_position,
    CAST(r.Position AS INT64) as final_position,
    CAST(r.GridPosition AS INT64) - CAST(r.Position AS INT64) as positions_gained,
    r.Points

  FROM stint_counts sc
  JOIN `topicos-bases-datos.f1_data_warehouse.results` r
    ON sc.EventName = r.EventName
    AND sc.Year = r.Year
    AND sc.Driver = r.Abbreviation

  WHERE
    r.SessionName = 'Race'
    AND r.Position IS NOT NULL
    
)

SELECT
  Year,
  EventName,
  stop_strategy,

  -- Tamaño de muestra
  COUNT(*) as drivers_count,

  -- Performance metrics
  ROUND(AVG(final_position), 2) as avg_final_position,
  ROUND(AVG(grid_position), 2) as avg_grid_position,
  ROUND(AVG(positions_gained), 2) as avg_positions_gained,
  ROUND(AVG(Points), 2) as avg_points,

  -- Distribución de resultados
  COUNTIF(final_position <= 3) as podium_count,
  COUNTIF(final_position <= 10) as points_finish_count,

  -- Mejor resultado
  MIN(final_position) as best_finish

FROM results_with_strategy

GROUP BY Year, EventName, stop_strategy

ORDER BY Year DESC, EventName,
  CASE stop_strategy
    WHEN '0-Stop' THEN 1
    WHEN '1-Stop' THEN 2
    WHEN '2-Stop' THEN 3
    ELSE 4
  END;


-- ==============================================================================
-- QUERY 2.5: Ventana Óptima de Parada por Circuito (Histórico)
-- ==============================================================================
-- Propósito: Identificar la ventana óptima histórica de primera parada
--            en cada circuito
--
-- Para Looker: Guía de estrategia por circuito
-- ==============================================================================

WITH historical_strategies AS (
  WITH pit_data AS (
    SELECT
      EventName, Year, Driver, Team, Stint, LapNumber,
      MIN(LapNumber) OVER (PARTITION BY EventName, Year, Driver, Stint) as stint_start
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE EventDate >= '2021-01-01' AND SessionName = 'Race'
      AND Deleted = FALSE AND Stint IS NOT NULL
  ),
  first_pit AS (
    SELECT
      EventName, Year, Driver, Team,
      MIN(CASE WHEN Stint = 2 THEN stint_start END) as pit_lap
    FROM pit_data
    GROUP BY EventName, Year, Driver, Team
  ),
  results AS (
    SELECT
      r.EventName, r.Year, r.Abbreviation as Driver,
      CAST(r.Position AS INT64) as final_pos,
      r.Points
    FROM `topicos-bases-datos.f1_data_warehouse.results` r
    WHERE r.Year >= 2021 AND r.SessionName = 'Race'
      AND r.Position IS NOT NULL
  )

  SELECT
    fp.EventName,
    fp.Year,
    fp.pit_lap,
    r.final_pos,
    r.Points,

    -- Clasificar en buckets de 5 vueltas
    CAST(FLOOR(fp.pit_lap / 5) * 5 AS INT64) as pit_window_start

  FROM first_pit fp
  JOIN results r
    ON fp.EventName = r.EventName
    AND fp.Year = r.Year
    AND fp.Driver = r.Driver
  WHERE fp.pit_lap IS NOT NULL
)

SELECT
  EventName,
  pit_window_start,
  CONCAT('Lap ', CAST(pit_window_start AS STRING), '-', CAST(pit_window_start + 4 AS STRING)) as pit_window,

  -- Datos agregados históricos (todos los años)
  COUNT(*) as total_instances,

  ROUND(AVG(final_pos), 2) as avg_final_position,
  ROUND(AVG(Points), 2) as avg_points,

  -- Tasa de podio
  ROUND(COUNTIF(final_pos <= 3) / COUNT(*) * 100, 1) as podium_rate_percent,

  -- Tasa de puntos
  ROUND(COUNTIF(final_pos <= 10) / COUNT(*) * 100, 1) as points_rate_percent

FROM historical_strategies

GROUP BY EventName, pit_window_start

-- Filtrar ventanas con muestra suficiente
HAVING COUNT(*) >= 5

ORDER BY EventName, pit_window_start;


-- ==============================================================================
-- NOTAS DE USO PARA LOOKER
-- ==============================================================================
--
-- 1. QUERY 2.1: Vista detallada de estrategias por piloto
--    - Filtros: Year, EventName, Team, strategy_cohort
--    - Visualización: Tabla con drill-down por piloto
--    - Métricas clave: positions_gained, final_position
--
-- 2. QUERY 2.2: Comparativa de cohortes
--    - Visualización: Barras agrupadas por cohort
--    - X: cohort (Early/Optimal/Late)
--    - Y: avg_positions_gained o avg_points
--    - Color/Facet: EventName
--
-- 3. QUERY 2.3: Undercut vs Overcut
--    - Visualización: Barras comparativas
--    - Métricas: success_rate_percent, avg_positions_gained
--    - Comparar side-by-side por circuito
--
-- 4. QUERY 2.4: 1-Stop vs 2-Stop
--    - Visualización: Stacked bars o tabla
--    - Mostrar distribución de estrategias por circuito
--    - Identificar circuitos favorables para cada estrategia
--
-- 5. QUERY 2.5: Guía de ventana óptima
--    - Visualización: Heatmap o tabla de referencia
--    - Usar como guía predictiva para próximas carreras
--    - Color: avg_points (verde = mejor ventana)
--
-- ==============================================================================
