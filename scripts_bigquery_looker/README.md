# Scripts BigQuery para Looker - F1 Analytics

Este directorio contiene las queries SQL optimizadas para BigQuery que alimentan los dashboards de Looker y la capa de servicio (DynamoDB).

## Estructura del Proyecto

```
scripts_bigquery_looker/
├── README.md                                  # Este archivo
├── 01_tyre_degradation_analysis.sql          # Objetivo 1: Degradación de neumáticos
├── 02_pit_stop_windows_analysis.sql          # Objetivo 2: Ventanas de pit stops
├── 03_weather_performance_correlation.sql    # Objetivo 3: Correlación climática
└── 04_driver_metrics_for_dynamodb.sql        # Objetivo 4: Métricas para DynamoDB
```

## Información de las Tablas en BigQuery

**Proyecto**: `topicos-bases-datos`
**Dataset**: `f1_data_warehouse`

### Tablas Disponibles

| Tabla | Filas | Tamaño | Particionamiento | Clustering |
|-------|-------|--------|------------------|------------|
| `laps_enriched` | 125,205 | 125 MB | `EventDate` (DATE) | `Driver`, `EventName`, `Country` |
| `results` | 2,558 | 0.8 MB | No | `Abbreviation`, `EventName`, `Year` |
| `weather` | 19,192 | 2 MB | No | `EventName`, `Year`, `SessionName` |
| `race_control` | 10,479 | 1.2 MB | No | `EventName`, `Year`, `Category` |

**Notas importantes**:
- En JOINs: `results.Abbreviation = laps_enriched.Driver` (mismo campo, diferente nombre)
- Siempre filtrar por `EventDate` en `laps_enriched` para aprovechar particionamiento
- Los campos TIME están en formato STRING `HH:MM:SS.SSSSSS`

---

## Script 01: Degradación de Neumáticos

**Archivo**: `01_tyre_degradation_analysis.sql`

### Objetivo
Analizar cómo los diferentes compuestos de neumáticos (SOFT, MEDIUM, HARD) se degradan durante la carrera en diferentes circuitos.

### Queries Incluidas

#### Query 1.1: Degradación de Neumáticos - Vista Principal
- **Propósito**: Datos granulares por vuelta con cálculo de degradación relativa
- **Para Looker**: Dashboard principal con gráfica de líneas
- **Visualización**:
  - Eje X: TyreLife (vueltas del neumático)
  - Eje Y: LapTimeSeconds
  - Color: Compound
  - Filtros: Year, EventName, Team, Driver

#### Query 1.2: Degradación Promedio por Compuesto y Circuito
- **Propósito**: Vista agregada para comparar compuestos
- **Para Looker**: Tabla comparativa o barras agrupadas
- **Métricas clave**: `avg_degradation_percent`, `avg_tyre_life`, `max_tyre_life`

#### Query 1.3: Análisis de Degradación por TyreLife Específico
- **Propósito**: Ver cómo evoluciona el tiempo para cada vuelta de vida del neumático
- **Para Looker**: Gráfica de líneas suavizada
- **Uso**: Identificar en qué vuelta el rendimiento cae significativamente

#### Query 1.4: Top Equipos por Gestión de Neumáticos
- **Propósito**: Ranking de equipos según gestión de neumáticos
- **Para Looker**: Tabla ordenada
- **Métrica principal**: `avg_degradation_correlation` (menor = mejor gestión)

### Ejemplo de Uso en Looker

```sql
-- Ejemplo: Degradación de neumáticos en Mónaco 2024
-- Usar Query 1.1 con estos filtros:
WHERE Year = 2024
  AND EventName = 'Monaco Grand Prix'
  AND Compound IN ('SOFT', 'MEDIUM', 'HARD')
```

---

## Script 02: Ventanas de Parada en Pits

**Archivo**: `02_pit_stop_windows_analysis.sql`

### Objetivo
Evaluar cuándo es óptimo hacer la primera parada en pits y cómo esto afecta el resultado final.

### Queries Incluidas

#### Query 2.1: Identificar Primera Parada de cada Piloto
- **Propósito**: Clasificar pilotos en cohortes estratégicas
- **Cohortes**:
  - Early Stop (Undercut): Parada en percentil <33
  - Optimal Window: Parada en percentil 33-66
  - Late Stop (Overcut): Parada en percentil >66
- **Para Looker**: Vista detallada por piloto

#### Query 2.2: Comparativa de Cohortes de Estrategia
- **Propósito**: Comparar métricas entre cohortes
- **Métricas clave**:
  - `avg_positions_gained`
  - `avg_points`
  - `finish_rate_percent`
- **Para Looker**: Barras agrupadas por cohort

#### Query 2.3: Análisis de Undercut vs Overcut
- **Propósito**: Qué estrategia es más efectiva por circuito
- **Métricas**: `success_rate_percent`, `avg_positions_gained`

#### Query 2.4: Impacto de Estrategias de 1 vs 2 Paradas
- **Propósito**: Comparar rendimiento multi-stop
- **Para Looker**: Tabla o barras comparativas

#### Query 2.5: Ventana Óptima de Parada por Circuito
- **Propósito**: Guía histórica de ventanas óptimas
- **Uso**: Referencia predictiva para próximas carreras
- **Ventanas**: Agrupadas en buckets de 5 vueltas (Lap 10-14, 15-19, etc.)

### Ejemplo de Uso

```sql
-- Ejemplo: ¿Cuál fue la ventana óptima en Silverstone?
-- Usar Query 2.5 filtrada por EventName = 'British Grand Prix'
-- Buscar pit_window con mejor avg_points
```

---

## Script 03: Correlación Climática y Rendimiento

**Archivo**: `03_weather_performance_correlation.sql`

### Objetivo
Analizar cómo las condiciones climáticas (temperatura, humedad, viento) afectan el rendimiento.

### Queries Incluidas

#### Query 3.1: Correlación Temperatura de Pista vs Tiempo de Vuelta
- **Propósito**: Datos granulares para scatter plots
- **Para Looker**: Scatter plot principal
- **Variables climáticas**:
  - `avg_track_temp`
  - `avg_air_temp`
  - `avg_humidity`
  - `avg_wind_speed`

#### Query 3.2: Análisis de Correlación por Circuito
- **Propósito**: Coeficientes de correlación entre clima y rendimiento
- **Métricas**:
  - `corr_tracktemp_laptime`
  - `corr_tracktemp_sector1speed`
  - `corr_humidity_laptime`
- **Interpretación**:
  - Correlación positiva = rendimiento empeora con temperatura alta
  - Correlación negativa = rendimiento mejora con temperatura alta

#### Query 3.3: Impacto de Temperatura por Compuesto
- **Propósito**: Ventana óptima de temperatura para cada compuesto
- **Para Looker**: Líneas múltiples (una por compuesto)
- **Uso**: Identificar "sweet spot" de temperatura

#### Query 3.4: Análisis de Sectores bajo Diferentes Condiciones de Viento
- **Propósito**: Qué sectores son más vulnerables al viento
- **Categorías de viento**:
  - Low Wind (<2 km/h)
  - Moderate Wind (2-5 km/h)
  - High Wind (5+ km/h)

#### Query 3.5: Predictor de Performance basado en Condiciones
- **Propósito**: Modelo simple de predicción
- **Métricas clave**:
  - `impact_seconds_per_degree_celsius`
  - `estimated_impact_plus_10_degrees`
- **Uso**: "Si la temperatura sube 10°C, ¿cuánto empeora el lap time?"

### Ejemplo de Uso

```sql
-- Ejemplo: ¿Cómo afecta el calor a los SOFT en Bahréin?
-- Usar Query 3.3 filtrada por:
WHERE EventName = 'Bahrain Grand Prix'
  AND Compound = 'SOFT'
-- Buscar temp_bucket con mejor avg_lap_seconds
```

---

## Script 04: Métricas de Piloto para DynamoDB

**Archivo**: `04_driver_metrics_for_dynamodb.sql`

### Objetivo
Calcular métricas complejas pre-agregadas para servir desde DynamoDB con baja latencia (<200ms).

### Queries Incluidas

#### Query 4.1: Tyre Management Index (Score 1-10)
- **Propósito**: Medir habilidad de gestión de neumáticos
- **Metodología**:
  - Comparar degradación del piloto vs promedio del grid
  - Analizar duración de stints
  - Contar stints largos exitosos (≥20 laps)
- **Score alto**: Excelente gestión de neumáticos

#### Query 4.2: Consistency Score (Score 1-10)
- **Propósito**: Medir consistencia de tiempos de vuelta
- **Metodología**:
  - Calcular coeficiente de variación (COV)
  - Comparar con promedio del grid
  - Menor COV = más consistente
- **Score alto**: Muy consistente

#### Query 4.3: Sector Performance Profile
- **Propósito**: Clasificar rendimiento por tipo de sector
- **Clasificación de sectores**:
  - High Speed: Velocidad promedio ≥200 km/h
  - Medium Speed: Velocidad promedio 150-200 km/h
  - Low Speed: Velocidad promedio <150 km/h
- **Ratings**: Elite, Above Average, Average, Below Average

#### Query 4.4: Perfil Consolidado de Piloto (PRINCIPAL)
- **Propósito**: Vista única con todas las métricas para cargar a DynamoDB
- **Output**: Un registro JSON por piloto-año
- **Estructura del JSON**:

```json
{
  "driver_code": "VER",
  "year": 2024,
  "tyre_management_index": 8.5,
  "consistency_score": 9.2,
  "sector_performance_profile": {
    "high_speed_performance": "Elite",
    "medium_speed_performance": "Above Average",
    "low_speed_performance": "Elite"
  },
  "races_entered": 22,
  "wins": 19,
  "podiums": 21,
  "total_points": 575.0,
  "avg_finish_position": 1.23,
  "best_finish": 1
}
```

### Proceso ETL a DynamoDB

1. **Ejecutar Query 4.4** en BigQuery
2. **Exportar resultados** a JSON/CSV
3. **Script Python** para cargar a DynamoDB:

```python
import boto3
from google.cloud import bigquery

# Cliente BigQuery
bq_client = bigquery.Client(project='topicos-bases-datos')

# Cliente DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('f1_driver_profiles')

# Ejecutar Query 4.4
query = """
-- Contenido de Query 4.4
"""
results = bq_client.query(query).result()

# Cargar a DynamoDB
for row in results:
    table.put_item(Item={
        'driver_code': row['driver_code'],
        'year': row['year'],
        'tyre_management_index': float(row['tyre_management_index']),
        'consistency_score': float(row['consistency_score']),
        'sector_performance_profile': row['sector_performance_profile'],
        # ... resto de campos
        'last_updated': datetime.now().isoformat()
    })
```

4. **API Endpoint** (AWS Lambda):

```python
# GET /api/driver/{driver_code}/profile?year=2024

import boto3

def lambda_handler(event, context):
    driver_code = event['pathParameters']['driver_code']
    year = int(event['queryStringParameters'].get('year', 2024))

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('f1_driver_profiles')

    response = table.get_item(
        Key={'driver_code': driver_code, 'year': year}
    )

    return {
        'statusCode': 200,
        'body': json.dumps(response.get('Item', {}))
    }
```

---

## Guía de Optimización

### Mejores Prácticas para Queries

#### 1. Siempre usar EventDate en laps_enriched
```sql
-- ✅ BIEN
WHERE EventDate = '2024-05-26'  -- Usa particionamiento
WHERE EventDate BETWEEN '2024-01-01' AND '2024-12-31'

-- ❌ MAL
WHERE Year = 2024  -- No usa particionamiento, escanea toda la tabla
```

#### 2. Aprovechar clustering en filtros
```sql
-- ✅ BIEN (orden sigue clustering: Driver, EventName, Country)
WHERE EventDate = '2024-05-26'
  AND Driver = 'VER'
  AND EventName = 'Monaco Grand Prix'
  AND Country = 'Monaco'

-- ❌ MAL (no sigue clustering)
WHERE Country = 'Monaco'
  AND Year = 2024
```

#### 3. Filtrar tabla grande primero en JOINs
```sql
-- ✅ BIEN
FROM laps_enriched l
WHERE l.EventDate BETWEEN '2024-01-01' AND '2024-12-31'  -- Filtrar primero
JOIN results r ON ...

-- ❌ MAL
FROM results r
JOIN laps_enriched l ON ...
WHERE l.Year = 2024  -- Filtrar después del JOIN
```

#### 4. Convertir campos TIME a segundos
```sql
-- Los campos TIME están como STRING: "00:01:23.456789"
-- Convertir a segundos para cálculos:

CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +  -- Horas
CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +    -- Minutos
CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)         -- Segundos
```

### Costos Estimados por Query

| Query | Bytes Procesados | Costo Estimado (USD) |
|-------|------------------|----------------------|
| 01.1 (todas las carreras 2021-2025) | ~125 MB | $0.0006 |
| 01.1 (una carrera específica) | ~0.5 MB | $0.000003 |
| 02.1 (todas las carreras) | ~125 MB + 0.8 MB | $0.0006 |
| 03.1 (todas las carreras) | ~125 MB + 2 MB | $0.0006 |
| 04.4 (todas las carreras) | ~125 MB + 0.8 MB | $0.0006 |

**Precios BigQuery**: $5 por TB procesado (primeros 1 TB gratis al mes)

---

## Testing de Queries

### Validar Query en BigQuery Console

1. Ir a [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Seleccionar proyecto: `topicos-bases-datos`
3. Copiar query del archivo `.sql`
4. Hacer clic en "Format query" (opcional)
5. Revisar "Bytes processed" en la esquina superior derecha
6. Ejecutar con "Run"

### Queries de Validación Rápidas

```sql
-- Verificar estructura de laps_enriched
SELECT * FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
LIMIT 10;

-- Contar registros por año
SELECT Year, COUNT(*) as count
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
GROUP BY Year
ORDER BY Year DESC;

-- Verificar JOIN entre laps y results
SELECT
  l.Driver,
  r.Abbreviation,
  COUNT(*) as matches
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` l
JOIN `topicos-bases-datos.f1_data_warehouse.results` r
  ON l.Driver = r.Abbreviation
  AND l.EventName = r.EventName
  AND l.Year = r.Year
WHERE l.EventDate = '2024-05-26'  -- Monaco
GROUP BY l.Driver, r.Abbreviation
ORDER BY matches DESC;
```

---

## Integración con Looker

### Crear Conexión a BigQuery en Looker

1. En Looker, ir a **Admin > Database > Connections**
2. Crear nueva conexión:
   - **Dialect**: Google BigQuery Standard SQL
   - **Project Name**: `topicos-bases-datos`
   - **Dataset**: `f1_data_warehouse`
   - **Service Account JSON**: (subir archivo de credenciales)
3. Probar conexión

### Crear Explores en LookML

```lookml
# f1_tyre_degradation.explore
explore: tyre_degradation {
  from: sql_table_name: (Query 01.1)

  dimension: driver {
    type: string
    sql: ${TABLE}.Driver ;;
  }

  dimension: tyre_life {
    type: number
    sql: ${TABLE}.TyreLife ;;
  }

  measure: avg_lap_time_seconds {
    type: average
    sql: ${TABLE}.LapTimeSeconds ;;
  }
}
```

### Crear Dashboard

1. Ir a **Explore** > Seleccionar explore
2. Configurar visualización:
   - **Visualization Type**: Line
   - **X-axis**: TyreLife
   - **Y-axis**: avg_lap_time_seconds
   - **Color**: Compound
   - **Filters**: Year, EventName
3. Guardar en dashboard

---

## Próximos Pasos

1. **Validar Queries**: Ejecutar cada query en BigQuery Console
2. **Optimizar si necesario**: Revisar bytes procesados
3. **Crear Explores en Looker**: Configurar LookML
4. **Desarrollar Dashboards**: Crear visualizaciones
5. **ETL a DynamoDB**: Ejecutar Query 4.4 y cargar resultados
6. **Desplegar API**: Lambda + API Gateway para servir perfiles de piloto

---

## Soporte y Referencias

- **BigQuery Schema Reference**: `3projectContext/bigquery_schema_reference.md`
- **SMART Objectives**: `3projectContext/smart.md`
- **Documentación BigQuery**: https://cloud.google.com/bigquery/docs
- **Documentación Looker**: https://docs.looker.com

---

**Última actualización**: 2025-10-13
**Versión**: 1.0
**Autor**: F1 Analytics Team
