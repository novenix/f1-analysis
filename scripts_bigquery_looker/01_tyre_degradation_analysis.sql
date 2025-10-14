-- ==============================================================================
-- OBJETIVO 1: ANÁLISIS DE DEGRADACIÓN DE NEUMÁTICOS POR COMPUESTO
-- ==============================================================================
-- Descripción: Dashboard interactivo para comparar rendimiento y degradación
--              de neumáticos (SOFT, MEDIUM, HARD, INTERMEDIATE, WET) en circuitos clave
--
-- Visualización objetivo: Gráfica de líneas
--   - Eje X: Número de vuelta del stint (TyreLife)
--   - Eje Y: Tiempo de vuelta
--   - Filtros: Circuito, Compuesto, Equipo, Año
--
-- Optimización: Usa particionamiento por EventDate y clustering por Driver/EventName
-- ==============================================================================

-- ==============================================================================
-- QUERY 1.1: Degradación de Neumáticos - Vista Principal
-- ==============================================================================
-- Propósito: Analizar cómo evoluciona el tiempo de vuelta según el desgaste
--            del neumático en carreras
--
-- Para Looker: Esta es la query base para el dashboard principal
-- ==============================================================================

WITH race_laps AS (
  SELECT
    -- Identificadores del evento
    EventName,
    EventDate,
    Year,
    Country,
    Location,
    SessionName,

    -- Identificadores del piloto y equipo
    Driver,
    DriverNumber,
    Team,

    -- Datos del stint y neumático
    Stint,
    Compound,
    TyreLife,
    FreshTyre,

    -- Tiempos de vuelta
    LapNumber,
    LapTime,

    -- Convertir LapTime (TIME) a segundos usando función nativa
    -- TIME_DIFF calcula diferencia desde medianoche (00:00:00)
    TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) AS LapTimeSeconds,

    -- Flags de estado
    IsPersonalBest,
    Deleted,
    DeletedReason,

    -- Datos de posición
    Position,

    -- Datos de velocidad por sector (para análisis adicional)
    Sector1_Speed_Avg,
    Sector2_Speed_Avg,
    Sector3_Speed_Avg,

    -- Track status para filtrar laps bajo Safety Car, VSC, etc.
    TrackStatus

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    -- ✅ OPTIMIZACIÓN: Usa particionamiento por EventDate
    EventDate >= '2021-01-01'

    -- Solo carreras (no clasificación, práctica, etc.)
    AND SessionName = 'Race'

    -- Filtrar vueltas válidas (no eliminadas)
    AND Deleted = FALSE

    -- Filtrar laps con tiempo válido (no NULL)
    AND LapTime IS NOT NULL

    -- Filtrar vueltas bajo condiciones normales
    -- TrackStatus: 1 = pista verde, 2 = bandera amarilla, 4 = Safety Car, 6 = VSC
    AND TrackStatus < 4  -- Green (1) o Yellow (2), excluye Safety Car

    -- Filtrar outliers de tiempo (vueltas muy lentas, pit stops, etc.)
    -- Asumimos que laps normales están entre 60s y 180s
    AND TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
),

-- Calcular estadísticas agregadas por stint
stint_stats AS (
  SELECT
    EventName,
    EventDate,
    Year,
    Country,
    Location,
    Driver,
    Team,
    Stint,
    Compound,

    -- Estadísticas del stint
    COUNT(*) as total_laps,
    MIN(TyreLife) as stint_start_tyre_life,
    MAX(TyreLife) as stint_end_tyre_life,
    MAX(TyreLife) - MIN(TyreLife) + 1 as stint_length,

    -- Tiempos promedio
    AVG(LapTimeSeconds) as avg_lap_time_seconds,
    MIN(LapTimeSeconds) as best_lap_time_seconds,
    MAX(LapTimeSeconds) as worst_lap_time_seconds,
    STDDEV(LapTimeSeconds) as lap_time_std_dev,

    -- Velocidades promedio
    AVG(Sector1_Speed_Avg) as avg_sector1_speed,
    AVG(Sector2_Speed_Avg) as avg_sector2_speed,
    AVG(Sector3_Speed_Avg) as avg_sector3_speed

  FROM race_laps

  -- Filtrar stints muy cortos (menos de 5 vueltas)
  GROUP BY EventName, EventDate, Year, Country, Location, Driver, Team, Stint, Compound
  HAVING COUNT(*) >= 5
)

-- Query final: Datos granulares por vuelta con contexto del stint
SELECT
  l.*,

  -- Calcular degradación relativa dentro del stint
  -- (tiempo actual - mejor tiempo del stint) / mejor tiempo
  ROUND((l.LapTimeSeconds - s.best_lap_time_seconds) / s.best_lap_time_seconds * 100, 3)
    as degradation_percent,

  -- Metadata del stint
  s.stint_length,
  s.avg_lap_time_seconds as stint_avg_time,
  s.best_lap_time_seconds as stint_best_time,
  s.lap_time_std_dev as stint_consistency,

  -- Formatear tiempo de vuelta legible
  CONCAT(
    CAST(CAST(l.LapTimeSeconds / 60 AS INT64) AS STRING), ':',
    FORMAT('%06.3f', CAST(MOD(l.LapTimeSeconds, 60) AS FLOAT64))
  ) as lap_time_formatted

FROM race_laps l
JOIN stint_stats s
  ON l.EventName = s.EventName
  AND l.Year = s.Year
  AND l.Driver = s.Driver
  AND l.Stint = s.Stint

-- Ordenar para facilitar visualización
ORDER BY
  l.Year DESC,
  l.EventDate DESC,
  l.Driver,
  l.Stint,
  l.TyreLife;


-- ==============================================================================
-- QUERY 1.2: Degradación Promedio por Compuesto y Circuito
-- ==============================================================================
-- Propósito: Vista agregada para comparar degradación entre compuestos
--            en diferentes circuitos
--
-- Para Looker: Gráfica de barras o tabla comparativa
-- ==============================================================================

WITH lap_degradation AS (
  SELECT
    EventName,
    Country,
    Year,
    Driver,
    Team,
    Stint,
    Compound,
    TyreLife,

    -- Convertir tiempo a segundos
    TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) AS lap_seconds,

    -- Mejor tiempo del stint (ventana)
    MIN(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) OVER (
      PARTITION BY EventName, Year, Driver, CAST(Stint AS INT64)
    ) as stint_best_seconds

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND LapTime IS NOT NULL
    AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag
    AND TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
)

SELECT
  EventName,
  Country,
  Year,
  Compound,

  -- Estadísticas por compuesto en cada circuito
  COUNT(DISTINCT CONCAT(Driver, '-', CAST(Stint AS STRING))) as total_stints,
  ROUND(AVG(lap_seconds), 3) as avg_lap_time_seconds,

  -- Degradación promedio por vuelta de vida del neumático
  -- Agrupar por TyreLife para ver cómo evoluciona
  ROUND(
    AVG((lap_seconds - stint_best_seconds) / stint_best_seconds * 100),
    3
  ) as avg_degradation_percent,

  -- Duración promedio de stint
  ROUND(AVG(TyreLife), 1) as avg_tyre_life,
  MAX(TyreLife) as max_tyre_life,

  -- Consistencia (desviación estándar de degradación)
  ROUND(STDDEV((lap_seconds - stint_best_seconds) / stint_best_seconds * 100), 3)
    as degradation_std_dev

FROM lap_degradation

GROUP BY EventName, Country, Year, Compound

ORDER BY Year DESC, EventName,
  CASE Compound
    WHEN 'SOFT' THEN 1
    WHEN 'MEDIUM' THEN 2
    WHEN 'HARD' THEN 3
    WHEN 'INTERMEDIATE' THEN 4
    WHEN 'WET' THEN 5
    ELSE 6
  END;


-- ==============================================================================
-- QUERY 1.3: Análisis de Degradación por TyreLife Específico
-- ==============================================================================
-- Propósito: Ver cómo cambia el tiempo de vuelta para cada vuelta de vida
--            del neumático (ej: vuelta 1, 5, 10, 15, 20, etc.)
--
-- Para Looker: Gráfica de líneas con TyreLife en eje X
-- ==============================================================================

WITH tyre_performance AS (
  SELECT
    EventName,
    Country,
    Year,
    Compound,
    TyreLife,

    -- Convertir tiempo
    TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) AS lap_seconds

  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`

  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND LapTime IS NOT NULL
    AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag
    AND TyreLife IS NOT NULL
    AND TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
)

SELECT
  EventName,
  Country,
  Year,
  Compound,
  TyreLife,

  -- Estadísticas por cada vuelta de vida del neumático
  COUNT(*) as sample_size,
  ROUND(AVG(lap_seconds), 3) as avg_lap_time_seconds,
  ROUND(MIN(lap_seconds), 3) as best_lap_time_seconds,
  ROUND(STDDEV(lap_seconds), 3) as lap_time_std_dev,

  -- Formatear tiempo promedio legible
  CONCAT(
    CAST(TRUNC(AVG(lap_seconds) / 60) AS STRING), ':',
    FORMAT('%06.3f', AVG(lap_seconds) - 60.0 * TRUNC(AVG(lap_seconds) / 60.0))
  ) as avg_lap_time_formatted

FROM tyre_performance

-- Filtrar TyreLives con suficiente muestra
GROUP BY EventName, Country, Year, Compound, TyreLife
HAVING COUNT(*) >= 3

ORDER BY Year DESC, EventName, Compound, TyreLife;


-- ==============================================================================
-- QUERY 1.4: Ranking de Equipos por Gestión de Neumáticos (por Circuito)
-- ==============================================================================
-- Propósito: Identificar qué equipos tienen la mejor gestión de neumáticos
--            (menor degradación) en un circuito y año específicos.
--
-- Para Looker: Ranking de equipos, filtrable por Año y EventName.
-- ==============================================================================
WITH stint_analysis AS (
  SELECT
    Year,
    Team,
    EventName,
    Driver,
    Stint,
    Compound,
    CORR(TyreLife, TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) as degradation_correlation,
    COUNT(*) as stint_laps,
    MAX(TyreLife) as max_tyre_life,
    AVG(TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND)) as avg_lap_seconds
  FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
  WHERE
    EventDate >= '2021-01-01'
    AND SessionName = 'Race'
    AND Deleted = FALSE
    AND LapTime IS NOT NULL
    AND TrackStatus < 4
    AND TyreLife IS NOT NULL
    AND TIME_DIFF(LapTime, TIME(0, 0, 0), SECOND) BETWEEN 60 AND 180
  GROUP BY Year, Team, EventName, Driver, Stint, Compound
  HAVING COUNT(*) >= 10
)

SELECT
  Year,
  Team,
  EventName, -- <-- CAMBIO CLAVE: AÑADIDO AQUÍ
  ROUND(AVG(degradation_correlation), 4) as avg_degradation_correlation,
  ROUND(AVG(max_tyre_life), 1) as avg_stint_duration,
  COUNT(*) as total_long_stints,
  ROUND(AVG(avg_lap_seconds), 3) as overall_avg_lap_time
FROM stint_analysis
GROUP BY Year, Team, EventName -- <-- CAMBIO CLAVE: Y AÑADIDO AQUÍ
ORDER BY Year DESC, EventName, avg_degradation_correlation ASC;

-- ==============================================================================
-- NOTAS DE USO PARA LOOKER
-- ==============================================================================
--
-- 1. QUERY 1.1: Usar como base para el dashboard principal
--    - Filtros recomendados: Year, EventName, Compound, Team, Driver
--    - Visualización: Línea con TyreLife (X) vs LapTimeSeconds (Y)
--    - Color por: Compound
--    - Facet por: EventName o Team
--
-- 2. QUERY 1.2: Usar para comparativa de circuitos
--    - Visualización: Tabla o barras agrupadas
--    - Grouping: EventName, Compound
--    - Métricas: avg_degradation_percent, avg_tyre_life
--
-- 3. QUERY 1.3: Usar para análisis detallado de degradación
--    - Visualización: Línea suavizada
--    - X: TyreLife
--    - Y: avg_lap_time_seconds
--    - Separate lines por: Compound
--
-- 4. QUERY 1.4: Usar para ranking de equipos por circuito
--    - Visualización: Tabla ordenada
--    - Sort: avg_degradation_correlation (ASC = mejor)
--    - Filtros clave: Year, EventName
--
-- ==============================================================================


-- ==============================================================================
-- GUÍA DE VISUALIZACIÓN EN LOOKER
-- ==============================================================================
-- 
-- --- GRÁFICO 1.1: Curva de Degradación por Piloto (Gráfico de Líneas) ---
-- 
-- Descripción de Negocio:
-- Esta es la vista más detallada. Muestra la "huella digital" del rendimiento de un piloto vuelta a vuelta.
-- Permite a un estratega ver exactamente cómo el tiempo de vuelta de un piloto específico cambia a medida que sus neumáticos se desgastan.
-- Responde preguntas como: "¿Fue consistente el ritmo de Hamilton en su stint con neumáticos medios?" o "¿En qué vuelta empezó a perder rendimiento Pérez?".
-- 
-- Elementos y Filtros:
-- - Eje X (Dimensión): TyreLife (Vida del neumático en vueltas).
-- - Eje Y (Métrica): LapTimeSeconds (Tiempo de vuelta en segundos, usar PROMEDIO/AVG).
-- - Desglose por Color (Breakdown): Compound (Crea una línea para cada compuesto: SOFT, MEDIUM, etc.).
-- - Filtros Clave: EventName, Year, Team, Driver (Esencial filtrar por piloto y carrera para un análisis claro).
-- 
-- --- GRÁFICO 1.2: Comparativa de Compuestos por Circuito (Gráfico de Barras Agrupadas) ---
-- 
-- Descripción de Negocio:
-- Ofrece una visión general de alto nivel. Compara el rendimiento promedio de cada compuesto de neumático en un circuito específico.
-- Es ideal para entender las características de una pista antes de la carrera.
-- Responde preguntas como: "En general, ¿qué compuesto se degrada más rápido en Silverstone?" o "¿Cuál es la duración promedio de un stint con neumáticos duros en Bahréin?".
-- 
-- Elementos y Filtros:
-- - Eje X (Dimensión): EventName (El circuito).
-- - Desglose por Barra (Breakdown): Compound (Crea una barra de color para cada compuesto).
-- - Eje Y (Métrica): avg_degradation_percent o avg_tyre_life.
-- - Filtros Clave: Year, Country.
-- 
-- --- GRÁFICO 1.3: Curva de Degradación Promedio del Circuito (Gráfico de Líneas) ---
-- 
-- Descripción de Negocio:
-- Muestra la curva de degradación "típica" o promedio de un circuito, combinando los datos de todos los pilotos.
-- Es la herramienta perfecta para identificar el "cliff" de rendimiento: la vuelta exacta en la que un compuesto empieza a ser significativamente más lento.
-- Responde la pregunta: "Para el compuesto SOFT en Monza, ¿a partir de qué vuelta el rendimiento empieza a caer drásticamente?".
-- 
-- Elementos y Filtros:
-- - Eje X (Dimensión): TyreLife.
-- - Eje Y (Métrica): avg_lap_time_seconds.
-- - Desglose por Color (Breakdown): Compound.
-- - Filtros Clave: EventName, Year (Esencial para ver la curva de una carrera específica).
-- 
-- --- GRÁFICO 1.4: Ranking de Equipos por Gestión de Neumáticos (Tabla Ordenada) ---
-- 
-- Descripción de Negocio:
-- Es un ranking de rendimiento que clasifica a los equipos según su habilidad para gestionar el desgaste de los neumáticos.
-- La métrica clave es 'avg_degradation_correlation': un valor bajo o negativo indica una gestión de élite.
-- Permite identificar qué equipos son mejores cuidando las gomas en una carrera específica o a lo largo de la temporada.
-- Responde preguntas como: "¿Qué equipo gestionó mejor los neumáticos en la última carrera?" o "¿Cuál es el mejor equipo de la temporada en stints largos?".
-- 
-- Elementos y Filtros:
-- - Dimensiones de la Tabla: Team, EventName.
-- - Métricas de la Tabla: avg_degradation_correlation, avg_stint_duration, total_long_stints.
-- - Orden de la Tabla (Sort): Por 'avg_degradation_correlation' en modo 'Ascendente' (menor es mejor).
-- - Filtros Clave: Year, EventName (Permite ver el ranking general del año o el específico de una carrera).
-- 
-- ==============================================================================