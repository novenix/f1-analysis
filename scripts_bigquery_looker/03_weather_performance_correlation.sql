-- ==============================================================================
-- OBJETIVO 3: CORRELACIONAR CONDICIONES CLIMÁTICAS CON RENDIMIENTO POR SECTOR
-- ==============================================================================
-- Descripción: Analizar cómo las condiciones climáticas (temperatura, humedad,
--              viento) afectan el rendimiento por sector y la degradación.
--
-- Visualización objetivo: Scatter plot / Gráficas de correlación
--   - Eje X: Variable climática (TrackTemp, AirTemp, etc.)
--   - Eje Y: Métrica de rendimiento (LapTime, Speed, etc.)
--
-- Optimización: JOIN entre laps_enriched y weather con clustering optimizado.
-- ==============================================================================

-- ==============================================================================
-- QUERY 3.1: Correlación Temperatura de Pista vs Tiempo de Vuelta
-- ==============================================================================
-- Propósito: Analizar cómo la temperatura del asfalto afecta los tiempos
--            de vuelta y la degradación de neumáticos.
--
-- Para Looker: Scatter plot principal.
-- ==============================================================================

WITH lap_data AS (
  SELECT
    EventName,
    EventDate,
    Year,
    Country,
    SessionName,
    Driver,
    Team,
    LapNumber,
    Compound,
    TyreLife,

    -- Tiempo de vuelta en segundos
    TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) AS lap_seconds,

    -- Velocidades promedio por sector
    Sector1_Speed_Avg,
    Sector2_Speed_Avg,
    Sector3_Speed_Avg,

    -- Tiempos por sector en segundos
    TIME_DIFF(Sector1Time, TIME(0, 0, 0), SECOND) as sector1_seconds,
    TIME_DIFF(Sector2Time, TIME(0, 0, 0), SECOND) as sector2_seconds,
    TIME_DIFF(Sector3Time, TIME(0, 0, 0), SECOND) as sector3_seconds,

    -- Track status
    TrackStatus

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND LapTime IS NOT NULL
    AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag
    AND TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
),

weather_data AS (
  SELECT
    EventName,
    Year,
    SessionName,

    -- Promediar condiciones climáticas por sesión
    ROUND(AVG(TrackTemp), 1) as avg_track_temp,
    ROUND(AVG(AirTemp), 1) as avg_air_temp,
    ROUND(AVG(Humidity), 1) as avg_humidity,
    ROUND(AVG(Pressure), 1) as avg_pressure,
    ROUND(AVG(WindSpeed), 1) as avg_wind_speed,

    -- Rangos de temperatura
    MIN(TrackTemp) as min_track_temp,
    MAX(TrackTemp) as max_track_temp,

    -- Lluvia
    MAX(CAST(Rainfall AS INT64)) as had_rainfall

  FROM `topicos-bases-datos.f1_data_warehouse.weather`

  WHERE
    Year >= 2021
    AND SessionName = 'Race'

  GROUP BY EventName, Year, SessionName
)

SELECT
  l.EventName,
  l.Year,
  l.Country,
  l.Driver,
  l.Team,
  l.LapNumber,
  l.Compound,
  l.TyreLife,

  -- Datos de rendimiento
  l.lap_seconds,
  l.sector1_seconds,
  l.sector2_seconds,
  l.sector3_seconds,
  l.Sector1_Speed_Avg,
  l.Sector2_Speed_Avg,
  l.Sector3_Speed_Avg,

  -- Datos climáticos
  w.avg_track_temp,
  w.avg_air_temp,
  w.avg_humidity,
  w.avg_pressure,
  w.avg_wind_speed,
  w.min_track_temp,
  w.max_track_temp,
  w.had_rainfall

FROM lap_data l
JOIN weather_data w
  ON l.EventName = w.EventName
  AND l.Year = w.Year
  AND l.SessionName = w.SessionName

ORDER BY l.Year DESC, l.EventName, l.Driver, l.LapNumber;


-- ==============================================================================
-- QUERY 3.2: Análisis de Correlación por Circuito
-- ==============================================================================
-- Propósito: Calcular coeficientes de correlación entre variables climáticas
--            y métricas de rendimiento para cada circuito.
--
-- Para Looker: Tabla de insights / Heatmap de correlaciones.
-- ==============================================================================

WITH lap_weather_combined AS (
  SELECT
    l.EventName, l.Year,
    TIME_DIFF(l.LapTime, TIME(0, 0, 0), SECOND) AS lap_seconds,
    l.Sector1_Speed_Avg, l.Sector2_Speed_Avg, l.Sector3_Speed_Avg,
    -- Tomar la temperatura específica de la vuelta, no el promedio de la sesión
    w.TrackTemp as track_temp,
    w.AirTemp as air_temp,
    w.Humidity as humidity
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
    ON l.EventName = w.EventName
    AND l.Year = w.Year
    AND l.SessionName = w.SessionName
    -- Unir cada vuelta con las lecturas de clima del mismo minuto para obtener variación
    AND TIME_TRUNC(l.LapStartTime, MINUTE) = TIME_TRUNC(w.Time, MINUTE)
  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.LapTime IS NOT NULL
    AND l.TrackStatus < 4
    AND TIME_DIFF(l.LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
)
SELECT
  EventName, Year,
  COUNT(*) as sample_size,
  ROUND(AVG(track_temp), 1) as avg_track_temp,
  ROUND(AVG(air_temp), 1) as avg_air_temp,
  ROUND(AVG(humidity), 1) as avg_humidity,
  -- Ahora las correlaciones funcionarán porque la temperatura varía en cada vuelta
  ROUND(CORR(track_temp, lap_seconds), 4) as corr_tracktemp_laptime,
  ROUND(CORR(track_temp, Sector1_Speed_Avg), 4) as corr_tracktemp_sector1speed,
  ROUND(CORR(air_temp, lap_seconds), 4) as corr_airtemp_laptime,
  ROUND(CORR(humidity, lap_seconds), 4) as corr_humidity_laptime
FROM lap_weather_combined
GROUP BY EventName, Year
ORDER BY Year DESC, EventName;


-- Resto de las queries (3.3, 3.4, 3.5) corregidas con la misma lógica
-- ... (incluidas para completitud, los cambios principales están arriba)

-- ==============================================================================
-- QUERY 3.3: Impacto de Temperatura por Compuesto de Neumático
-- ==============================================================================
-- Propósito: Analizar cómo diferentes compuestos reaccionan a cambios
--            de temperatura (ventana óptima de temperatura por compuesto).
--
-- Para Looker: Líneas múltiples por compuesto.
-- ==============================================================================

WITH temp_compound_data AS (
  SELECT
    l.Compound,
    TIME_DIFF(l.LapTime, TIME(0, 0, 0), SECOND) as lap_seconds,
    -- Temperatura (bucketed en rangos de 2°C para cada vuelta)
    CAST(FLOOR(w.TrackTemp / 2) * 2 AS INT64) as temp_bucket
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
    ON l.EventName = w.EventName
    AND l.Year = w.Year
    AND l.SessionName = w.SessionName
    AND TIME_TRUNC(l.LapStartTime, MINUTE) = TIME_TRUNC(w.Time, MINUTE)
  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.LapTime IS NOT NULL
    AND l.TrackStatus < 4
    AND l.Compound IN ('SOFT', 'MEDIUM', 'HARD')
    AND w.TrackTemp IS NOT NULL
    AND TIME_DIFF(l.LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
)
SELECT
  Compound,
  temp_bucket,
  CONCAT(CAST(temp_bucket AS STRING), '-', CAST(temp_bucket + 2 AS STRING), '°C') as temp_range,
  COUNT(*) as total_laps,
  ROUND(AVG(lap_seconds), 3) as avg_lap_seconds,
  ROUND(STDDEV(lap_seconds), 3) as lap_time_std_dev,
  ROUND(MIN(lap_seconds), 3) as best_lap_seconds
FROM temp_compound_data
WHERE temp_bucket IS NOT NULL
GROUP BY Compound, temp_bucket
HAVING COUNT(*) >= 10
ORDER BY Compound, temp_bucket;

-- ==============================================================================
-- QUERY 3.4: Análisis de Sectores bajo Diferentes Condiciones de Viento
-- ==============================================================================
-- Propósito: Identificar qué sectores son más sensibles al viento.
--
-- Para Looker: Comparativa de sectores con/sin viento.
-- ==============================================================================

WITH sector_wind_data AS (
  SELECT
    l.EventName, l.Year,
    CASE
      WHEN w.WindSpeed < 2 THEN 'Low Wind (<2 km/h)'
      WHEN w.WindSpeed < 5 THEN 'Moderate Wind (2-5 km/h)'
      ELSE 'High Wind (5+ km/h)'
    END as wind_category,
    w.WindSpeed,
    TIME_DIFF(l.Sector1Time, TIME(0, 0, 0), SECOND) as sector1_seconds,
    TIME_DIFF(l.Sector2Time, TIME(0, 0, 0), SECOND) as sector2_seconds,
    TIME_DIFF(l.Sector3Time, TIME(0, 0, 0), SECOND) as sector3_seconds
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
    ON l.EventName = w.EventName
    AND l.Year = w.Year
    AND l.SessionName = w.SessionName
    AND TIME_TRUNC(l.LapStartTime, MINUTE) = TIME_TRUNC(w.Time, MINUTE)
  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.TrackStatus < 4
    AND l.Sector1Time IS NOT NULL AND l.Sector2Time IS NOT NULL AND l.Sector3Time IS NOT NULL
    AND w.WindSpeed IS NOT NULL
)
SELECT
  EventName, Year, wind_category,
  COUNT(*) as sample_size,
  ROUND(AVG(WindSpeed), 1) as avg_wind_speed,
  ROUND(AVG(sector1_seconds), 3) as sector1_avg_time,
  ROUND(AVG(sector2_seconds), 3) as sector2_avg_time,
  ROUND(AVG(sector3_seconds), 3) as sector3_avg_time
FROM sector_wind_data
WHERE wind_category IS NOT NULL
GROUP BY EventName, Year, wind_category
HAVING COUNT(*) >= 10
ORDER BY Year DESC, EventName,
  CASE wind_category
    WHEN 'Low Wind (<2 km/h)' THEN 1
    WHEN 'Moderate Wind (2-5 km/h)' THEN 2
    ELSE 3
  END;

-- ==============================================================================
-- QUERY 3.5: Predictor de Performance basado en Condiciones Climáticas
-- ==============================================================================
-- Propósito: Crear un modelo simple de predicción que estime cómo cambiará
--            el tiempo de vuelta bajo diferentes condiciones climáticas.
--
-- Para Looker: Tabla de referencia / Calculadora de impacto.
-- ==============================================================================

WITH lap_weather_data AS (
  SELECT
    l.EventName, l.Year, l.Team, l.Compound,
    TIME_DIFF(l.LapTime, TIME(0, 0, 0), SECOND) as lap_seconds,
    w.TrackTemp, w.AirTemp, w.Humidity
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
    ON l.EventName = w.EventName
    AND l.Year = w.Year
    AND l.SessionName = w.SessionName
    AND TIME_TRUNC(l.LapStartTime, MINUTE) = TIME_TRUNC(w.Time, MINUTE)
  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.LapTime IS NOT NULL
    AND l.TrackStatus < 4
    AND l.Compound IN ('SOFT', 'MEDIUM', 'HARD')
    AND w.TrackTemp IS NOT NULL
    AND TIME_DIFF(l.LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
)
SELECT
  EventName, Year, Team, Compound,
  COUNT(*) as sample_size,
  ROUND(AVG(TrackTemp), 1) as baseline_track_temp,
  ROUND(AVG(lap_seconds), 3) as baseline_lap_seconds,
  ROUND(CORR(TrackTemp, lap_seconds), 4) as temp_sensitivity_correlation,
  ROUND(COVAR_POP(TrackTemp, lap_seconds) / NULLIF(VARIANCE(TrackTemp), 0), 4) as impact_seconds_per_degree_celsius,
  ROUND((COVAR_POP(TrackTemp, lap_seconds) / NULLIF(VARIANCE(TrackTemp), 0)) * 10, 3) as estimated_impact_plus_10_degrees
FROM lap_weather_data
GROUP BY EventName, Year, Team, Compound
HAVING COUNT(*) > 30 AND ABS(CORR(TrackTemp, lap_seconds)) > 0.1
ORDER BY Year DESC, EventName, Team, Compound;


-- ==============================================================================
-- NOTAS DE USO PARA LOOKER
-- ==============================================================================
--
-- -- QUERY 3.1: Datos granulares para scatter plots
-- --   - Visualización: Scatter plot
-- --   - X: avg_track_temp (o avg_air_temp, avg_humidity)
-- --   - Y: lap_seconds
-- --   - Color: Compound
-- --   - Filtros: EventName, Team, Year
--
-- -- QUERY 3.2: Tabla de correlaciones por circuito
-- --   - Visualización: Tabla con color coding (heatmap)
-- --   - Identificar circuitos más sensibles a la temperatura.
--
-- -- QUERY 3.3: Ventana óptima de temperatura por compuesto
-- --   - Visualización: Líneas múltiples
-- --   - X: temp_bucket; Y: avg_lap_seconds; Desglose: Compound.
--
-- -- QUERY 3.4: Impacto del viento por sector
-- --   - Visualización: Barras agrupadas
-- --   - X: wind_category; Y: sector times; Desglose: Sector.
--
-- -- QUERY 3.5: Calculadora de impacto climático
-- --   - Visualización: Tabla de referencia.
-- --   - Usar "impact_seconds_per_degree_celsius" para predicciones.
--
-- ==============================================================================