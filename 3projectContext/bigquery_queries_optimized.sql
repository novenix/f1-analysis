-- Queries Optimizadas para BigQuery - F1 Analytics
-- =========================================================
-- Estas queries aprovechan el particionamiento por EventDate
-- y el clustering por Driver, EventName, Country

-- REGLAS DE OPTIMIZACIÓN:
-- 1. SIEMPRE usa EventDate (o BETWEEN) en WHERE para filtrar particiones
-- 2. Filtra por campos de clustering (Driver, EventName, Country) cuando sea posible
-- 3. Orden de importancia: EventDate > EventName > Driver > Country
-- 4. Evita SELECT * - selecciona solo columnas necesarias

-- =========================================================
-- PATRÓN 1: Análisis por Piloto y Evento
-- =========================================================

-- Ejemplo: Degradación de neumáticos de Verstappen en Bahrain 2024
SELECT
  LapNumber,
  Compound,
  TyreLife,
  CAST(LapTime AS STRING) as LapTime,
  Sector1_Speed_Avg,
  Sector2_Speed_Avg,
  Sector3_Speed_Avg
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE EventDate = '2024-03-02'           -- ✅ PARTICIÓN
  AND Driver = 'VER'                     -- ✅ CLUSTERING nivel 1
  AND EventName = 'Bahrain Grand Prix'  -- ✅ CLUSTERING nivel 2
  AND SessionName = 'Race'
ORDER BY LapNumber;
-- Bytes procesados estimados: ~0.1 MB


-- =========================================================
-- PATRÓN 2: Comparación entre Pilotos en un Evento
-- =========================================================

-- Ejemplo: Top 5 pilotos por velocidad promedio en Monaco 2024
SELECT
  Driver,
  Team,
  COUNT(*) as total_laps,
  ROUND(AVG(Sector1_Speed_Avg), 2) as avg_speed_s1,
  ROUND(AVG(Sector2_Speed_Avg), 2) as avg_speed_s2,
  ROUND(AVG(Sector3_Speed_Avg), 2) as avg_speed_s3
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE EventDate BETWEEN '2024-05-24' AND '2024-05-26'  -- ✅ PARTICIÓN (fin de semana)
  AND EventName = 'Monaco Grand Prix'                   -- ✅ CLUSTERING nivel 2
  AND Country = 'Monaco'                                 -- ✅ CLUSTERING nivel 3
  AND SessionName = 'Race'
GROUP BY Driver, Team
ORDER BY avg_speed_s1 DESC
LIMIT 5;
-- Bytes procesados estimados: ~0.5 MB


-- =========================================================
-- PATRÓN 3: Análisis Temporal (Multi-año)
-- =========================================================

-- Ejemplo: Evolución de tiempos de vuelta en Silverstone (2021-2024)
SELECT
  Year,
  Driver,
  MIN(CAST(LapTime AS STRING)) as best_lap,
  COUNT(*) as total_laps,
  ROUND(AVG(Sector1_Speed_Avg), 2) as avg_speed_s1,
  ROUND(AVG(Sector2_Speed_Avg), 2) as avg_speed_s2,
  ROUND(AVG(Sector3_Speed_Avg), 2) as avg_speed_s3
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE Country = 'Great Britain'           -- ✅ CLUSTERING nivel 3
  AND EventName = 'British Grand Prix'    -- ✅ CLUSTERING nivel 2
  AND SessionName = 'Race'
  AND Year BETWEEN 2021 AND 2024
GROUP BY Year, Driver
HAVING total_laps > 10  -- Solo pilotos que completaron al menos 10 vueltas
ORDER BY Year, avg_speed_s1 DESC;
-- Nota: Sin EventDate exacto, escanea más datos (~5 MB)
-- Mejora: Añadir EventDate BETWEEN si conoces las fechas


-- =========================================================
-- PATRÓN 4: Análisis por País/Región
-- =========================================================

-- Ejemplo: Rendimiento de equipos en circuitos de Italia
SELECT
  Year,
  EventName,
  Team,
  COUNT(*) as total_laps,
  ROUND(AVG(Sector1_Speed_Avg), 2) as avg_speed
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE Country = 'Italy'                   -- ✅ CLUSTERING nivel 3
  AND SessionName = 'Race'
GROUP BY Year, EventName, Team
ORDER BY Year DESC, avg_speed DESC;
-- Bytes procesados: ~3 MB (múltiples eventos en Italia)


-- =========================================================
-- PATRÓN 5: Análisis de Neumáticos
-- =========================================================

-- Ejemplo: Degradación promedio por compuesto en un circuito
-- Usa la estrategia de ventana temporal
SELECT
  Compound,
  TyreLife,
  COUNT(*) as laps_count,
  ROUND(AVG(Sector1_Speed_Avg), 2) as avg_speed_s1,
  ROUND(AVG(Sector2_Speed_Avg), 2) as avg_speed_s2,
  ROUND(AVG(Sector3_Speed_Avg), 2) as avg_speed_s3
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE EventDate BETWEEN '2024-03-22' AND '2024-03-24'  -- ✅ PARTICIÓN (Australia 2024)
  AND EventName = 'Australian Grand Prix'               -- ✅ CLUSTERING
  AND SessionName = 'Race'
  AND TyreLife <= 30  -- Solo primeras 30 vueltas de cada stint
GROUP BY Compound, TyreLife
HAVING laps_count > 5  -- Solo datos con suficiente muestra
ORDER BY Compound, TyreLife;
-- Bytes procesados: ~0.6 MB


-- =========================================================
-- PATRÓN 6: Unir con tabla Weather
-- =========================================================

-- Ejemplo: Correlación temperatura de pista vs velocidad
SELECT
  l.EventName,
  l.Driver,
  ROUND(AVG(w.TrackTemp), 1) as avg_track_temp,
  ROUND(AVG(l.Sector1_Speed_Avg), 2) as avg_speed
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
  ON l.EventName = w.EventName
  AND l.Year = w.Year
  AND l.SessionName = w.SessionName
WHERE l.EventDate = '2024-07-07'          -- ✅ PARTICIÓN
  AND l.EventName = 'British Grand Prix'  -- ✅ CLUSTERING
  AND l.SessionName = 'Race'
GROUP BY l.EventName, l.Driver
ORDER BY avg_speed DESC;
-- Bytes procesados: ~0.8 MB (incluye JOIN pequeño con weather)


-- =========================================================
-- PATRÓN 7: Análisis de Sectores (Clasificación de velocidad)
-- =========================================================

-- Ejemplo: Identificar sectores rápidos vs lentos
-- Esto es útil para el Objetivo 1 (clasificación de sectores)
SELECT
  EventName,
  Country,
  ROUND(AVG(Sector1_Speed_Avg), 2) as sector1_avg_speed,
  ROUND(AVG(Sector2_Speed_Avg), 2) as sector2_avg_speed,
  ROUND(AVG(Sector3_Speed_Avg), 2) as sector3_avg_speed,
  -- Clasificar sectores
  CASE
    WHEN AVG(Sector1_Speed_Avg) > 200 THEN 'High Speed'
    WHEN AVG(Sector1_Speed_Avg) > 150 THEN 'Medium Speed'
    ELSE 'Low Speed'
  END as sector1_type
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE Year = 2024
  AND SessionName = 'Race'
GROUP BY EventName, Country
ORDER BY sector1_avg_speed DESC;
-- Nota: Sin EventDate específico, escanea todo 2024 (~30 MB)
-- Usa esto para análisis exploratorio, no para queries frecuentes


-- =========================================================
-- PATRÓN 8: Estadísticas de Piloto Completas (Para DynamoDB)
-- =========================================================

-- Ejemplo: Calcular métricas agregadas de un piloto (para perfil)
-- Esta query se ejecutaría periódicamente para actualizar DynamoDB
SELECT
  'VER' as driver_id,
  COUNT(DISTINCT EventName) as races_participated,
  COUNT(CASE WHEN Position = 1 THEN 1 END) as race_wins,
  ROUND(AVG(Sector1_Speed_Avg), 2) as avg_speed_all_circuits,
  ROUND(STDDEV(Sector1_Speed_Avg), 2) as speed_consistency,
  -- Mejor circuito (por velocidad promedio)
  (SELECT EventName
   FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
   WHERE Driver = 'VER' AND SessionName = 'Race'
   GROUP BY EventName
   ORDER BY AVG(Sector1_Speed_Avg) DESC
   LIMIT 1) as best_circuit
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE Driver = 'VER'                      -- ✅ CLUSTERING nivel 1
  AND SessionName = 'Race'
  AND Year BETWEEN 2021 AND 2024;
-- Bytes procesados: ~2 MB (todo Verstappen 2021-2024)


-- =========================================================
-- ANTI-PATRONES (Evitar)
-- =========================================================

-- ❌ MAL: No usa partición ni clustering
-- SELECT * FROM laps_enriched
-- WHERE SessionName = 'Race';
-- Escanearía: 124.87 MB completos

-- ❌ MAL: Solo usa Year (no es partición)
-- SELECT * FROM laps_enriched
-- WHERE Year = 2024;
-- Escanearía: ~30 MB (todas las particiones de 2024)

-- ✅ BIEN: Usa EventDate + clustering
-- SELECT * FROM laps_enriched
-- WHERE EventDate BETWEEN '2024-01-01' AND '2024-12-31'
--   AND Driver = 'VER';
-- Escanearía: ~2 MB (solo particiones de 2024 + clustering por VER)
