-- ==============================================================================
-- OBJETIVO 3: CORRELACIONAR CONDICIONES CLIMÁTICAS CON RENDIMIENTO POR SECTOR
-- ==============================================================================
-- Descripción: Analizar cómo las condiciones climáticas (temperatura, humedad,
--              viento) afectan el rendimiento por sector y la degradación
--
-- Visualización objetivo: Scatter plot / Gráficas de correlación
--   - Eje X: Variable climática (TrackTemp, AirTemp, etc.)
--   - Eje Y: Métrica de rendimiento (LapTime, Speed, etc.)
--   - Análisis por sector individual
--
-- Optimización: JOIN entre laps_enriched y weather con clustering optimizado
-- ==============================================================================

-- ==============================================================================
-- QUERY 3.1: Correlación Temperatura de Pista vs Tiempo de Vuelta
-- ==============================================================================
-- Propósito: Analizar cómo la temperatura del asfalto afecta los tiempos
--            de vuelta y la degradación de neumáticos
--
-- Para Looker: Scatter plot principal
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
    CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
    CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
    CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64) AS lap_seconds,

    -- Velocidades promedio por sector
    Sector1_Speed_Avg,
    Sector2_Speed_Avg,
    Sector3_Speed_Avg,

    -- Tiempos por sector en segundos
    CASE
        CAST(SPLIT(Sector1Time, ':')[SAFE_OFFSET(0)] AS INT64) * 3600 +
        CAST(SPLIT(Sector1Time, ':')[SAFE_OFFSET(1)] AS INT64) * 60 +
        CAST(SPLIT(Sector1Time, ':')[SAFE_OFFSET(2)] AS FLOAT64)
    END as sector1_seconds,

    CASE
        CAST(SPLIT(Sector2Time, ':')[SAFE_OFFSET(0)] AS INT64) * 3600 +
        CAST(SPLIT(Sector2Time, ':')[SAFE_OFFSET(1)] AS INT64) * 60 +
        CAST(SPLIT(Sector2Time, ':')[SAFE_OFFSET(2)] AS FLOAT64)
    END as sector2_seconds,

    CASE
        CAST(SPLIT(Sector3Time, ':')[SAFE_OFFSET(0)] AS INT64) * 3600 +
        CAST(SPLIT(Sector3Time, ':')[SAFE_OFFSET(1)] AS INT64) * 60 +
        CAST(SPLIT(Sector3Time, ':')[SAFE_OFFSET(2)] AS FLOAT64)
    END as sector3_seconds,

    -- Track status
    TrackStatus

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND LapTime IS NOT NULL
    AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag  -- Pista verde
    AND (
      CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) BETWEEN 60 AND 180
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
--            y métricas de rendimiento para cada circuito
--
-- Para Looker: Tabla de insights / Heatmap de correlaciones
-- ==============================================================================

WITH lap_weather_combined AS (
  SELECT
    l.EventName,
    l.Year,

    -- Tiempo de vuelta
    CAST(SPLIT(l.LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
    CAST(SPLIT(l.LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
    CAST(SPLIT(l.LapTime, ':')[OFFSET(2)] AS FLOAT64) AS lap_seconds,

    -- Velocidades
    l.Sector1_Speed_Avg,
    l.Sector2_Speed_Avg,
    l.Sector3_Speed_Avg,

    -- Clima (promedio de sesión)
    AVG(w.TrackTemp) OVER (PARTITION BY l.EventName, l.Year, l.SessionName) as track_temp,
    AVG(w.AirTemp) OVER (PARTITION BY l.EventName, l.Year, l.SessionName) as air_temp,
    AVG(w.Humidity) OVER (PARTITION BY l.EventName, l.Year, l.SessionName) as humidity

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
    ON l.EventName = w.EventName
    AND l.Year = w.Year
    AND l.SessionName = w.SessionName

  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.LapTime IS NOT NULL
    
    AND l.TrackStatus IN ('1', '124')
    AND (
      CAST(SPLIT(l.LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) BETWEEN 60 AND 180
)

SELECT
  EventName,
  Year,

  -- Tamaño de muestra
  COUNT(*) as sample_size,

  -- Promedios climáticos
  ROUND(AVG(track_temp), 1) as avg_track_temp,
  ROUND(AVG(air_temp), 1) as avg_air_temp,
  ROUND(AVG(humidity), 1) as avg_humidity,

  -- Correlaciones: TrackTemp vs Performance
  ROUND(CORR(track_temp, lap_seconds), 4) as corr_tracktemp_laptime,
  ROUND(CORR(track_temp, Sector1_Speed_Avg), 4) as corr_tracktemp_sector1speed,
  ROUND(CORR(track_temp, Sector2_Speed_Avg), 4) as corr_tracktemp_sector2speed,
  ROUND(CORR(track_temp, Sector3_Speed_Avg), 4) as corr_tracktemp_sector3speed,

  -- Correlaciones: AirTemp vs Performance
  ROUND(CORR(air_temp, lap_seconds), 4) as corr_airtemp_laptime,
  ROUND(CORR(air_temp, Sector1_Speed_Avg), 4) as corr_airtemp_sector1speed,

  -- Correlaciones: Humidity vs Performance
  ROUND(CORR(humidity, lap_seconds), 4) as corr_humidity_laptime,
  ROUND(CORR(humidity, Sector1_Speed_Avg), 4) as corr_humidity_sector1speed,

  -- Performance metrics
  ROUND(AVG(lap_seconds), 2) as avg_lap_seconds,
  ROUND(STDDEV(lap_seconds), 2) as lap_time_std_dev

FROM lap_weather_combined

GROUP BY EventName, Year

ORDER BY Year DESC, EventName;


-- ==============================================================================
-- QUERY 3.3: Impacto de Temperatura por Compuesto de Neumático
-- ==============================================================================
-- Propósito: Analizar cómo diferentes compuestos reaccionan a cambios
--            de temperatura (ventana óptima de temperatura por compuesto)
--
-- Para Looker: Líneas múltiples por compuesto
-- ==============================================================================

WITH temp_compound_data AS (
  SELECT
    l.EventName,
    l.Year,
    l.Compound,

    -- Temperatura (bucketed en rangos de 2°C)
    CAST(FLOOR(AVG(w.TrackTemp) / 2) * 2 AS INT64) as temp_bucket,

    -- Performance
    AVG(
      CAST(SPLIT(l.LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as avg_lap_seconds,

    COUNT(*) as sample_size

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
    ON l.EventName = w.EventName
    AND l.Year = w.Year
    AND l.SessionName = w.SessionName

  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.LapTime IS NOT NULL
    
    AND l.TrackStatus IN ('1', '124')
    AND l.Compound IN ('SOFT', 'MEDIUM', 'HARD')
    AND w.TrackTemp IS NOT NULL
    AND (
      CAST(SPLIT(l.LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) BETWEEN 60 AND 180

  GROUP BY l.EventName, l.Year, l.Compound, temp_bucket
)

SELECT
  Compound,
  temp_bucket,
  CONCAT(CAST(temp_bucket AS STRING), '-', CAST(temp_bucket + 2 AS STRING), '°C') as temp_range,

  -- Agregado multi-circuito
  COUNT(DISTINCT CONCAT(EventName, '-', CAST(Year AS STRING))) as circuits_count,
  SUM(sample_size) as total_laps,

  -- Performance promedio en ese rango de temperatura
  ROUND(AVG(avg_lap_seconds), 3) as avg_lap_seconds,
  ROUND(STDDEV(avg_lap_seconds), 3) as lap_time_std_dev,

  -- Mejor caso
  ROUND(MIN(avg_lap_seconds), 3) as best_avg_lap_seconds

FROM temp_compound_data

-- Filtrar rangos con muestra suficiente
WHERE sample_size >= 10

GROUP BY Compound, temp_bucket

ORDER BY Compound,
  CASE Compound
    WHEN 'SOFT' THEN 1
    WHEN 'MEDIUM' THEN 2
    WHEN 'HARD' THEN 3
  END,
  temp_bucket;


-- ==============================================================================
-- QUERY 3.4: Análisis de Sectores bajo Diferentes Condiciones de Viento
-- ==============================================================================
-- Propósito: Identificar qué sectores son más sensibles al viento
--            (útil para setup aerodinámico)
--
-- Para Looker: Comparativa de sectores con/sin viento
-- ==============================================================================

WITH sector_wind_data AS (
  SELECT
    l.EventName,
    l.Year,
    l.Driver,
    l.Team,

    -- Clasificar viento
    CASE
      WHEN AVG(w.WindSpeed) < 2 THEN 'Low Wind (<2 km/h)'
      WHEN AVG(w.WindSpeed) < 5 THEN 'Moderate Wind (2-5 km/h)'
      ELSE 'High Wind (5+ km/h)'
    END as wind_category,

    AVG(w.WindSpeed) as avg_wind_speed,

    -- Velocidades por sector
    AVG(l.Sector1_Speed_Avg) as avg_sector1_speed,
    AVG(l.Sector2_Speed_Avg) as avg_sector2_speed,
    AVG(l.Sector3_Speed_Avg) as avg_sector3_speed,

    -- Tiempos por sector
    AVG(
      CAST(SPLIT(l.Sector1Time, ':')[SAFE_OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.Sector1Time, ':')[SAFE_OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.Sector1Time, ':')[SAFE_OFFSET(2)] AS FLOAT64)
    ) as avg_sector1_seconds,

    AVG(
      CAST(SPLIT(l.Sector2Time, ':')[SAFE_OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.Sector2Time, ':')[SAFE_OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.Sector2Time, ':')[SAFE_OFFSET(2)] AS FLOAT64)
    ) as avg_sector2_seconds,

    AVG(
      CAST(SPLIT(l.Sector3Time, ':')[SAFE_OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.Sector3Time, ':')[SAFE_OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.Sector3Time, ':')[SAFE_OFFSET(2)] AS FLOAT64)
    ) as avg_sector3_seconds,

    COUNT(*) as lap_count

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
    ON l.EventName = w.EventName
    AND l.Year = w.Year
    AND l.SessionName = w.SessionName

  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.LapTime IS NOT NULL
    AND l.TrackStatus IN ('1', '124')
    AND l.Sector1Time IS NOT NULL
    AND l.Sector2Time IS NOT NULL
    AND l.Sector3Time IS NOT NULL
    AND w.WindSpeed IS NOT NULL

  GROUP BY l.EventName, l.Year, l.Driver, l.Team, wind_category
  HAVING COUNT(*) >= 5
)

SELECT
  EventName,
  Year,
  wind_category,

  COUNT(DISTINCT Driver) as drivers_count,
  ROUND(AVG(avg_wind_speed), 1) as avg_wind_speed,

  -- Sector 1 (usualmente alta velocidad/rectas largas)
  ROUND(AVG(avg_sector1_speed), 1) as sector1_avg_speed,
  ROUND(AVG(avg_sector1_seconds), 3) as sector1_avg_time,

  -- Sector 2 (usualmente técnico/curvas rápidas)
  ROUND(AVG(avg_sector2_speed), 1) as sector2_avg_speed,
  ROUND(AVG(avg_sector2_seconds), 3) as sector2_avg_time,

  -- Sector 3 (usualmente curvas lentas)
  ROUND(AVG(avg_sector3_speed), 1) as sector3_avg_speed,
  ROUND(AVG(avg_sector3_seconds), 3) as sector3_avg_time

FROM sector_wind_data

GROUP BY EventName, Year, wind_category

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
--            el tiempo de vuelta bajo diferentes condiciones climáticas
--
-- Para Looker: Tabla de referencia / Calculadora de impacto
-- ==============================================================================

WITH baseline_performance AS (
  -- Calcular performance base (condiciones promedio)
  SELECT
    l.EventName,
    l.Year,
    l.Team,
    l.Compound,

    -- Condiciones climáticas promedio
    ROUND(AVG(w.TrackTemp), 1) as baseline_track_temp,
    ROUND(AVG(w.AirTemp), 1) as baseline_air_temp,
    ROUND(AVG(w.Humidity), 1) as baseline_humidity,

    -- Performance base
    AVG(
      CAST(SPLIT(l.LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as baseline_lap_seconds,

    COUNT(*) as sample_size

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
    ON l.EventName = w.EventName
    AND l.Year = w.Year
    AND l.SessionName = w.SessionName

  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.LapTime IS NOT NULL
    AND l.TrackStatus IN ('1', '124')
    AND l.Compound IN ('SOFT', 'MEDIUM', 'HARD')
    AND (
      CAST(SPLIT(l.LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) BETWEEN 60 AND 180

  GROUP BY l.EventName, l.Year, l.Team, l.Compound
  HAVING COUNT(*) >= 20
),

sensitivity_analysis AS (
  -- Calcular sensibilidad (impacto por grado de temperatura)
  SELECT
    l.EventName,
    l.Year,
    l.Team,
    l.Compound,

    -- Correlación temperatura-tiempo
    CORR(
      w.TrackTemp,
      CAST(SPLIT(l.LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) as temp_correlation,

    -- Coeficiente de impacto (segundos por grado Celsius)
    COVAR_POP(
      w.TrackTemp,
      CAST(SPLIT(l.LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) / VARIANCE(w.TrackTemp) as seconds_per_degree

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
  JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
    ON l.EventName = w.EventName
    AND l.Year = w.Year
    AND l.SessionName = w.SessionName

  WHERE
    l.EventDate >= '2021-01-01'
    AND l.SessionName = 'Race'
    AND l.Deleted = FALSE
    AND l.LapTime IS NOT NULL
    AND l.TrackStatus IN ('1', '124')
    AND l.Compound IN ('SOFT', 'MEDIUM', 'HARD')
    AND w.TrackTemp IS NOT NULL
    AND (
      CAST(SPLIT(l.LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
      CAST(SPLIT(l.LapTime, ':')[OFFSET(2)] AS FLOAT64)
    ) BETWEEN 60 AND 180

  GROUP BY l.EventName, l.Year, l.Team, l.Compound
)

SELECT
  b.EventName,
  b.Year,
  b.Team,
  b.Compound,

  -- Baseline
  b.baseline_track_temp,
  b.baseline_air_temp,
  b.baseline_humidity,
  ROUND(b.baseline_lap_seconds, 3) as baseline_lap_seconds,

  -- Sensibilidad
  ROUND(s.temp_correlation, 4) as temp_sensitivity_correlation,
  ROUND(s.seconds_per_degree, 4) as impact_seconds_per_degree_celsius,

  -- Ejemplo: Impacto de +10°C
  ROUND(s.seconds_per_degree * 10, 3) as estimated_impact_plus_10_degrees,

  -- Ejemplo: Impacto de -5°C
  ROUND(s.seconds_per_degree * -5, 3) as estimated_impact_minus_5_degrees,

  b.sample_size

FROM baseline_performance b
JOIN sensitivity_analysis s
  ON b.EventName = s.EventName
  AND b.Year = s.Year
  AND b.Team = s.Team
  AND b.Compound = s.Compound

WHERE ABS(s.temp_correlation) > 0.1  -- Solo mostrar correlaciones significativas

ORDER BY b.Year DESC, b.EventName, b.Team,
  CASE b.Compound
    WHEN 'SOFT' THEN 1
    WHEN 'MEDIUM' THEN 2
    WHEN 'HARD' THEN 3
  END;


-- ==============================================================================
-- NOTAS DE USO PARA LOOKER
-- ==============================================================================
--
-- 1. QUERY 3.1: Datos granulares para scatter plots
--    - Visualización: Scatter plot
--    - X: avg_track_temp (o avg_air_temp, avg_humidity)
--    - Y: lap_seconds
--    - Color: Compound
--    - Filtros: EventName, Team, Year
--
-- 2. QUERY 3.2: Tabla de correlaciones por circuito
--    - Visualización: Tabla con color coding
--    - Identificar circuitos más sensibles a temperatura
--    - Correlación positiva = empeora con calor
--    - Correlación negativa = mejora con calor
--
-- 3. QUERY 3.3: Ventana óptima de temperatura por compuesto
--    - Visualización: Líneas múltiples
--    - X: temp_bucket
--    - Y: avg_lap_seconds
--    - Separate lines: Compound
--    - Identificar "sweet spot" de temperatura
--
-- 4. QUERY 3.4: Impacto del viento por sector
--    - Visualización: Barras agrupadas
--    - X: wind_category
--    - Y: sector times
--    - Group by: Sector
--    - Identificar sectores vulnerables al viento
--
-- 5. QUERY 3.5: Calculadora de impacto climático
--    - Visualización: Tabla de referencia
--    - Usar "impact_seconds_per_degree_celsius" para predicciones
--    - Ejemplo: Si la temperatura sube 10°C, agregar N segundos al lap time
--
-- ==============================================================================
