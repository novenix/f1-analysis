# BigQuery - Referencia de Esquema y Optimizaciones

## Proyecto: F1 Analytics - topicos-bases-datos
## Dataset: f1_data_warehouse

---

## Tablas en BigQuery

### 1. laps_enriched (Tabla Principal)

**Descripción**: Tabla principal con datos de telemetría por vuelta, enriquecida y desnormalizada.

**Optimizaciones**:
- ✅ **Particionamiento**: Por campo `EventDate` (día del evento)
- ✅ **Clustering**: `["Driver", "EventName", "Country"]`

**Estadísticas**:
- Filas: 125,205
- Tamaño: 124.87 MB
- Años: 2021-2025

**Columnas Clave**:
- `Driver` - Código del piloto (ej: HAM, VER, LEC)
- `EventName` - Nombre del GP (ej: "Monaco Grand Prix")
- `EventDate` - Fecha del evento (DATE) - **USAR PARA PARTICIONAR**
- `Country` - País del GP
- `Location` - Ciudad/circuito
- `Year` - Año (INTEGER)
- `SessionName` - Tipo de sesión (Race, Qualifying, etc.)
- `Sector1_Speed_Avg`, `Sector2_Speed_Avg`, `Sector3_Speed_Avg` - Velocidades promedio
- `Compound` - Tipo de neumático (SOFT, MEDIUM, HARD)
- `TyreLife` - Vueltas del neumático
- `Position` - Posición en la vuelta
- `Team` - Nombre del equipo

**Columnas Desnormalizadas de Events**:
- `OfficialEventName`
- `EventFormat`

---

### 2. results

**Descripción**: Resultados finales de cada sesión por piloto.

**Optimizaciones**:
- ❌ **Particionamiento**: No tiene partición (tabla pequeña <1 MB)
- ✅ **Clustering**: `["Abbreviation", "EventName", "Year"]`

**Estadísticas**:
- Filas: 2,558
- Tamaño: 0.79 MB
- Años: 2021-2025

**Columnas Clave**:
- `Abbreviation` - Código del piloto (ej: HAM, VER, LEC) ⚠️ **EQUIVALENTE A `Driver` en laps_enriched**
- `DriverId` - ID del piloto (ej: hamilton, verstappen)
- `FullName` - Nombre completo (ej: "Lewis Hamilton")
- `EventName` - Nombre del GP
- `Year` - Año (INTEGER)
- `SessionName` - Tipo de sesión
- `TeamName` - Nombre del equipo
- `Position` - Posición final
- `Points` - Puntos obtenidos
- `GridPosition` - Posición en parrilla
- `Status` - Estado final (Finished, +1 Lap, DNF, etc.)
- `Q1`, `Q2`, `Q3` - Tiempos de clasificación

**⚠️ IMPORTANTE**:
- En JOINs con `laps_enriched`, usar: `results.Abbreviation = laps_enriched.Driver`
- `Abbreviation` y `Driver` son el mismo campo, solo diferente nombre

---

### 3. weather

**Descripción**: Datos meteorológicos durante las sesiones.

**Optimizaciones**:
- ❌ **Particionamiento**: No tiene partición (tabla pequeña <2 MB)
- ✅ **Clustering**: `["EventName", "Year", "SessionName"]`

**Estadísticas**:
- Filas: 19,192
- Tamaño: 1.99 MB
- Años: 2021-2025

**Columnas Clave**:
- `EventName` - Nombre del GP
- `Year` - Año (INTEGER)
- `SessionName` - Tipo de sesión
- `Time` - Timestamp dentro de la sesión
- `TrackTemp` - Temperatura de la pista (°C)
- `AirTemp` - Temperatura del aire (°C)
- `Humidity` - Humedad (%)
- `Rainfall` - ¿Está lloviendo? (BOOLEAN)
- `WindSpeed` - Velocidad del viento (km/h)
- `WindDirection` - Dirección del viento (grados)
- `Pressure` - Presión atmosférica (hPa)

---

### 4. race_control

**Descripción**: Mensajes de control de carrera (banderas, safety car, etc.).

**Optimizaciones**:
- ❌ **Particionamiento**: No tiene partición (tabla pequeña <2 MB)
- ✅ **Clustering**: `["EventName", "Year", "Category"]`

**Estadísticas**:
- Filas: 10,479
- Tamaño: 1.21 MB
- Años: 2021-2025

**Columnas Clave**:
- `EventName` - Nombre del GP
- `Year` - Año (INTEGER)
- `Category` - Tipo de mensaje (Flag, SafetyCar, Other, etc.)
- `Time` - Timestamp del mensaje
- `Message` - Contenido del mensaje
- `Flag` - Tipo de bandera (Yellow, Red, Green, etc.)
- `Scope` - Alcance (Track, Driver, Sector)
- `RacingNumber` - Número del piloto afectado
- `Lap` - Vuelta del mensaje

---

## Estrategia de Optimización

### Cuándo usar Particionamiento:
- ✅ `laps_enriched`: Tabla grande (>100 MB) → **Particionada por `EventDate`**
- ❌ Tablas auxiliares: Pequeñas (<2 MB) → **No necesitan particionamiento**

### Cuándo usar Clustering:
- ✅ **Todas las tablas tienen clustering** para optimizar JOINs y filtros

---

## Guía de Queries Optimizadas

### 1. Query solo en laps_enriched

```sql
-- SIEMPRE usa EventDate para aprovechar particionamiento
SELECT Driver, AVG(Sector1_Speed_Avg) as avg_speed
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE EventDate = '2024-05-26'           -- ✅ PARTICIÓN
  AND EventName = 'Monaco Grand Prix'    -- ✅ CLUSTERING
  AND Driver = 'VER'                     -- ✅ CLUSTERING
GROUP BY Driver;
```

**Bytes procesados**: ~0.1 MB (vs 125 MB sin optimización)

---

### 2. Query con JOIN (laps_enriched + results)

```sql
-- Ejemplo: Race wins con velocidad promedio
SELECT
  r.Abbreviation as driver,
  r.FullName,
  COUNT(CASE WHEN r.Position = 1 THEN 1 END) as wins,
  ROUND(AVG(l.Sector1_Speed_Avg), 2) as avg_speed
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
JOIN `topicos-bases-datos.f1_data_warehouse.results` r
  ON r.Abbreviation = l.Driver      -- ⚠️ Abbreviation = Driver
  AND r.EventName = l.EventName
  AND r.Year = l.Year
WHERE l.EventDate BETWEEN '2024-01-01' AND '2024-12-31'  -- ✅ PARTICIÓN en laps
  AND r.SessionName = 'Race'
  AND l.SessionName = 'Race'
GROUP BY r.Abbreviation, r.FullName
ORDER BY wins DESC;
```

**Beneficio del clustering**:
- BigQuery ve que laps está filtrada por 2024
- Clustering en results salta directamente a bloques de 2024
- **Bytes procesados**: ~30 MB (laps 2024) + ~0.2 MB (results 2024)

---

### 3. Query con JOIN (laps_enriched + weather)

```sql
-- Ejemplo: Correlación temperatura vs velocidad
SELECT
  l.EventName,
  ROUND(AVG(w.TrackTemp), 1) as avg_track_temp,
  ROUND(AVG(l.Sector1_Speed_Avg), 2) as avg_speed
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
JOIN `topicos-bases-datos.f1_data_warehouse.weather` w
  ON w.EventName = l.EventName
  AND w.Year = l.Year
  AND w.SessionName = l.SessionName
WHERE l.EventDate = '2024-05-26'          -- ✅ PARTICIÓN
  AND l.EventName = 'Monaco Grand Prix'   -- ✅ CLUSTERING
GROUP BY l.EventName;
```

**Bytes procesados**: ~0.5 MB (laps Monaco) + ~0.01 MB (weather Monaco)

---

## Mapeo de Campos entre Tablas

### Campo "Driver/Piloto" en cada tabla:

| Tabla | Nombre del Campo | Ejemplo | Tipo |
|-------|-----------------|---------|------|
| `laps_enriched` | `Driver` | HAM | STRING |
| `results` | `Abbreviation` | HAM | STRING |
| `weather` | ❌ No tiene | - | - |
| `race_control` | `RacingNumber` | 44 | STRING (número del auto) |

**⚠️ Para JOINs**: `results.Abbreviation = laps_enriched.Driver`

---

### Campo "Evento/GP" en todas las tablas:

| Tabla | Campo | Ejemplo |
|-------|-------|---------|
| `laps_enriched` | `EventName` | Monaco Grand Prix |
| `results` | `EventName` | Monaco Grand Prix |
| `weather` | `EventName` | Monaco Grand Prix |
| `race_control` | `EventName` | Monaco Grand Prix |

✅ **Consistente en todas las tablas** → Fácil para JOINs

---

### Campo "Año" en todas las tablas:

| Tabla | Campo | Tipo |
|-------|-------|------|
| `laps_enriched` | `Year` | INTEGER |
| `results` | `Year` | INTEGER |
| `weather` | `Year` | INTEGER |
| `race_control` | `Year` | INTEGER |

✅ **Consistente en todas las tablas**

---

## Mejores Prácticas

### 1. Siempre usa EventDate en laps_enriched
```sql
WHERE EventDate = '2024-05-26'                    -- Día específico
WHERE EventDate BETWEEN '2024-05-24' AND '2024-05-26'  -- Fin de semana
```

### 2. Aprovecha clustering en filtros
```sql
WHERE Driver = 'VER'              -- Clustering nivel 1
  AND EventName = 'Monaco'        -- Clustering nivel 2
  AND Country = 'Monaco'          -- Clustering nivel 3
```

### 3. En JOINs, filtra la tabla grande primero
```sql
-- ✅ BIEN: Filtra laps primero (con partición)
FROM laps_enriched l
WHERE l.EventDate = '2024-05-26'
JOIN results r ON ...

-- ❌ MAL: No filtras la tabla grande
FROM results r
JOIN laps_enriched l ON ...
```

---

## Scripts de Configuración

### Carga inicial:
- `load_data_to_bigquery.py` - Carga todas las tablas (ejecutado 2025-10-05)

### Aplicar clustering:
- `apply_clustering_bigquery.py` - Aplica clustering a results, weather, race_control (ejecutado 2025-10-05)

### Verificación:
```python
from google.cloud import bigquery
client = bigquery.Client(project='topicos-bases-datos')

table = client.get_table('topicos-bases-datos.f1_data_warehouse.laps_enriched')
print(f"Partición: {table.time_partitioning.field}")
print(f"Clustering: {table.clustering_fields}")
```

---

## Resumen Visual

```
┌─────────────────────────────────────────────────────────────┐
│                    LAPS_ENRICHED                            │
│  (125K filas, 125 MB)                                       │
│  📅 Partición: EventDate                                    │
│  🔗 Clustering: Driver, EventName, Country                  │
│  ↓ Driver = Abbreviation en results                         │
└─────────────────────────────────────────────────────────────┘
                          ↓ JOIN
┌──────────────────┬──────────────────┬──────────────────────┐
│    RESULTS       │     WEATHER      │   RACE_CONTROL       │
│  (2.5K, 0.8 MB)  │  (19K, 2 MB)     │   (10K, 1.2 MB)      │
│  🔗 Abbreviation │  🔗 EventName    │   🔗 EventName       │
│     EventName    │     Year         │      Year            │
│     Year         │     SessionName  │      Category        │
└──────────────────┴──────────────────┴──────────────────────┘
```

---

**Última actualización**: 2025-10-05
**Versión**: 1.0
