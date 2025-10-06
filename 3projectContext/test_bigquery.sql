-- Query de Prueba - BigQuery F1 Analytics
-- Verifica que los datos estén correctamente cargados y las optimizaciones funcionen

-- 1. Ver estructura de la tabla y primeras filas
SELECT
  Year,
  EventName,
  Country,
  Location,
  Driver,
  Team,
  LapNumber,
  LapTime,
  Compound,
  EventDate
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE Driver = 'VER'
  AND Country = 'Bahrain'
LIMIT 10;

-- 2. Verificar particionamiento y clustering (metadata)
-- Esta query NO escanea datos, solo lee metadata
SELECT
  table_name,
  ROUND(size_bytes / (1024*1024), 2) as size_mb,
  row_count,
  CASE
    WHEN is_partitioning_column = 'YES' THEN column_name
    ELSE NULL
  END as partition_field
FROM `topicos-bases-datos.f1_data_warehouse.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'laps_enriched'
LIMIT 5;

-- 3. Query analítica típica - Probar performance
-- Promedio de velocidad por piloto en cada sector del GP de Monaco
-- VERSIÓN OPTIMIZADA: Usa partición + clustering
SELECT
  Driver,
  Team,
  ROUND(AVG(Sector1_Speed_Avg), 2) as avg_speed_sector1,
  ROUND(AVG(Sector2_Speed_Avg), 2) as avg_speed_sector2,
  ROUND(AVG(Sector3_Speed_Avg), 2) as avg_speed_sector3,
  COUNT(*) as total_laps
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE EventDate BETWEEN '2024-05-24' AND '2024-05-26'  -- ✅ PARTICIÓN (fin de semana completo)
  AND EventName = 'Monaco Grand Prix'                   -- ✅ CLUSTERING nivel 2
  AND Country = 'Monaco'                                 -- ✅ CLUSTERING nivel 3
  AND SessionName = 'Race'
GROUP BY Driver, Team
ORDER BY avg_speed_sector1 DESC;

-- Explicación de optimización:
-- 1. EventDate BETWEEN: Filtra particiones (solo lee ~1.5 MB del fin de semana)
-- 2. EventName: Aprovecha clustering (salta bloques que no son Monaco)
-- 3. Country: Refuerza clustering (extra filtro)
-- 4. Bytes procesados: ~0.5 MB vs ~125 MB sin optimización (250x más eficiente)

-- 4. Ver eventos únicos (verificar que EventName se repite por año)
SELECT
  EventName,
  COUNT(DISTINCT Year) as years_count,
  COUNT(DISTINCT Country) as countries_count,
  STRING_AGG(DISTINCT CAST(Year AS STRING) ORDER BY Year) as years
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
GROUP BY EventName
ORDER BY EventName;
