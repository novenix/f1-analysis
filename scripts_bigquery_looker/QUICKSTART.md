# Quick Start Guide - Scripts BigQuery para Looker

Guía rápida para empezar a usar los scripts de BigQuery para análisis de F1.

## 📋 Resumen Ejecutivo

**Proyecto**: F1 Analytics - topicos-bases-datos
**Dataset**: f1_data_warehouse
**Tablas**: laps_enriched, results, weather, race_control
**Período de datos**: 2021-2025

---

## 🚀 Inicio Rápido (5 minutos)

### 1. Verificar Acceso a BigQuery

```bash
# Opción A: Desde Google Cloud Console
# Ir a: https://console.cloud.google.com/bigquery
# Proyecto: topicos-bases-datos
# Dataset: f1_data_warehouse

# Opción B: Desde Python
python3 << EOF
from google.cloud import bigquery
client = bigquery.Client(project='topicos-bases-datos')
print("✅ Acceso correcto a BigQuery")
EOF
```

### 2. Probar una Query Simple

```sql
-- Copiar y pegar en BigQuery Console
SELECT
  EventName,
  Year,
  COUNT(*) as total_laps
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE EventDate >= '2024-01-01'
GROUP BY EventName, Year
ORDER BY Year DESC, EventName;
```

**Bytes procesados**: ~1 MB
**Tiempo estimado**: 2 segundos
**Resultado esperado**: Lista de carreras 2024-2025 con conteo de vueltas

### 3. Probar Query Principal de Degradación

```sql
-- Query 01.1 simplificada (solo Monaco 2024)
SELECT
  Driver,
  Team,
  Compound,
  TyreLife,
  AVG(
    CAST(SPLIT(LapTime, ':')[OFFSET(0)] AS INT64) * 3600 +
    CAST(SPLIT(LapTime, ':')[OFFSET(1)] AS INT64) * 60 +
    CAST(SPLIT(LapTime, ':')[OFFSET(2)] AS FLOAT64)
  ) as avg_lap_seconds
FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
WHERE
  EventDate = '2024-05-26'  -- Monaco 2024
  AND SessionName = 'Race'
  AND Deleted = FALSE
  AND LapTime IS NOT NULL
  AND Compound IN ('SOFT', 'MEDIUM', 'HARD')
GROUP BY Driver, Team, Compound, TyreLife
ORDER BY Driver, TyreLife;
```

**Bytes procesados**: ~0.5 MB
**Tiempo estimado**: 1-2 segundos
**Resultado**: Degradación de neumáticos por piloto en Mónaco

---

## 📁 Archivos Principales

| Archivo | Objetivo | Queries | Uso Principal |
|---------|----------|---------|---------------|
| `01_tyre_degradation_analysis.sql` | Degradación de neumáticos | 4 queries | Dashboard principal de Looker |
| `02_pit_stop_windows_analysis.sql` | Ventanas de pit stops | 5 queries | Análisis estratégico |
| `03_weather_performance_correlation.sql` | Correlación climática | 5 queries | Scatter plots y correlaciones |
| `04_driver_metrics_for_dynamodb.sql` | Métricas de piloto | 4 queries | ETL a DynamoDB |
| `README.md` | Documentación completa | - | Referencia técnica |
| `test_queries.py` | Script de testing | - | Probar queries desde Python |

---

## 🎯 Casos de Uso por Objetivo

### Objetivo 1: ¿Cómo se degradan los neumáticos?

**Query recomendada**: 01.1 o 01.2

**Pregunta de negocio**:
- ¿Cuántas vueltas puede hacer un SOFT en Silverstone antes de perder 1 segundo?
- ¿Qué compuesto dura más en Bahréin?

**Ejemplo de filtros en Looker**:
```
Year: 2024
EventName: British Grand Prix
Compound: SOFT, MEDIUM, HARD
```

**Visualización sugerida**: Línea con TyreLife (X) vs LapTime (Y), color por Compound

---

### Objetivo 2: ¿Cuándo debo parar en pits?

**Query recomendada**: 02.2 o 02.5

**Pregunta de negocio**:
- ¿Es mejor hacer undercut (parar temprano) o overcut (parar tarde) en Monza?
- ¿Cuál es la ventana óptima de primera parada en Barcelona?

**Ejemplo de filtros en Looker**:
```
Year: 2024
EventName: Italian Grand Prix
strategy_cohort: Early Stop, Optimal Window, Late Stop
```

**Visualización sugerida**: Barras agrupadas comparando avg_positions_gained por cohort

---

### Objetivo 3: ¿Cómo afecta el clima?

**Query recomendada**: 03.1 o 03.3

**Pregunta de negocio**:
- Si la temperatura sube 10°C, ¿cuánto empeora el lap time?
- ¿Qué compuesto rinde mejor en condiciones de calor?

**Ejemplo de filtros en Looker**:
```
Compound: SOFT
temp_range: 30-40°C
```

**Visualización sugerida**: Scatter plot con TrackTemp (X) vs LapTime (Y), color por Compound

---

### Objetivo 4: Perfiles de Piloto para API

**Query recomendada**: 04.4

**Pregunta de negocio**:
- ¿Qué piloto tiene mejor gestión de neumáticos?
- ¿Quién es más consistente en stints largos?

**Proceso**:
1. Ejecutar Query 04.4 en BigQuery
2. Exportar resultados a JSON
3. Cargar a DynamoDB
4. Servir desde API con latencia <200ms

---

## 🔍 Queries más Útiles por Categoría

### Para Dashboards de Looker

1. **Query 01.1**: Degradación granular (base del dashboard principal)
2. **Query 02.2**: Comparativa de estrategias (cohortes)
3. **Query 03.1**: Correlación clima-rendimiento (scatter plots)

### Para Análisis Ad-Hoc

1. **Query 01.4**: Ranking de equipos por gestión de neumáticos
2. **Query 02.3**: Undercut vs Overcut por circuito
3. **Query 03.5**: Predictor de impacto climático

### Para ETL y Productización

1. **Query 04.4**: Perfil consolidado de piloto (DynamoDB)

---

## ⚡ Tips de Performance

### Filtrar por Fecha SIEMPRE
```sql
-- ✅ BIEN (usa particionamiento)
WHERE EventDate = '2024-05-26'

-- ❌ MAL (escanea toda la tabla)
WHERE Year = 2024 AND EventName = 'Monaco Grand Prix'
```

### Usar Clustering en Orden
```sql
-- ✅ BIEN (sigue clustering: Driver, EventName, Country)
WHERE Driver = 'VER'
  AND EventName = 'Monaco Grand Prix'
  AND Country = 'Monaco'

-- ❌ MAL (no sigue clustering)
WHERE Country = 'Monaco'
```

### Limitar Resultados en Testing
```sql
-- Agregar LIMIT al final para testing rápido
SELECT ...
FROM ...
WHERE ...
LIMIT 100;  -- ✅ Testing
```

---

## 🧪 Testing con Python

### Listar todas las queries
```bash
python test_queries.py --list
```

### Preview de una query (sin ejecutar)
```bash
python test_queries.py --query 01.1 --preview
```

### Dry run (calcular bytes sin ejecutar)
```bash
python test_queries.py --query 01.1 --dry-run
```

### Ejecutar query con límite
```bash
python test_queries.py --query 01.1 --limit 100
```

### Ejecutar query completa
```bash
python test_queries.py --query 04.4
```

---

## 📊 Ejemplos de Resultados Esperados

### Query 01.2: Degradación por Compuesto

| EventName | Compound | avg_degradation_percent | avg_tyre_life |
|-----------|----------|-------------------------|---------------|
| Bahrain Grand Prix | SOFT | 2.34 | 15.2 |
| Bahrain Grand Prix | MEDIUM | 1.87 | 22.5 |
| Bahrain Grand Prix | HARD | 1.45 | 28.3 |

**Interpretación**: Los SOFT se degradan ~2.34% más rápido que el mejor lap del stint

---

### Query 02.2: Comparativa de Estrategias

| EventName | cohort | avg_positions_gained | avg_points |
|-----------|--------|----------------------|------------|
| Monaco Grand Prix | Early Stop | 0.8 | 6.2 |
| Monaco Grand Prix | Optimal Window | 1.2 | 8.5 |
| Monaco Grand Prix | Late Stop | -0.3 | 4.1 |

**Interpretación**: En Mónaco, la ventana óptima ganó ~1.2 posiciones en promedio

---

### Query 03.2: Correlaciones Clima

| EventName | corr_tracktemp_laptime | corr_humidity_laptime |
|-----------|------------------------|------------------------|
| Singapore | +0.45 | +0.32 |
| Abu Dhabi | +0.28 | -0.12 |

**Interpretación**:
- Singapur: Lap time empeora con calor (+correlación positiva)
- Abu Dhabi: Menos sensible a temperatura

---

### Query 04.4: Perfil de Piloto

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
  }
}
```

**Interpretación**: Verstappen tiene excelente gestión de neumáticos (8.5/10) y es élite en sectores de alta y baja velocidad

---

## 🎨 Configuración en Looker (Básico)

### 1. Crear Vista LookML

```lookml
# f1_tyre_degradation.view

view: tyre_degradation {
  sql_table_name: (
    -- Pegar Query 01.1 aquí
  );;

  dimension: driver {
    type: string
    sql: ${TABLE}.Driver ;;
  }

  dimension: tyre_life {
    type: number
    sql: ${TABLE}.TyreLife ;;
  }

  measure: avg_lap_time {
    type: average
    sql: ${TABLE}.lap_seconds ;;
  }
}
```

### 2. Crear Dashboard

1. Ir a **Explore** > Seleccionar vista
2. Configurar:
   - X: TyreLife
   - Y: avg_lap_time
   - Color: Compound
   - Filtros: Year = 2024
3. Save > Add to Dashboard

---

## 🆘 Solución de Problemas

### Error: "Access Denied"
```bash
# Verificar credenciales
gcloud auth application-default login
gcloud config set project topicos-bases-datos
```

### Error: "Table not found"
```sql
-- Verificar que la tabla existe
SELECT * FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched` LIMIT 1;
```

### Query muy lenta
```sql
-- Agregar filtro de fecha
WHERE EventDate >= '2024-01-01'  -- ✅ Usa particionamiento

-- Reducir alcance para testing
LIMIT 1000
```

### Bytes procesados muy altos
```bash
# Usar dry run para revisar
python test_queries.py --query 01.1 --dry-run
```

---

## 📚 Recursos Adicionales

- **Documentación Completa**: Ver [README.md](./README.md)
- **Schema Reference**: Ver `../3projectContext/bigquery_schema_reference.md`
- **Objetivos SMART**: Ver `../3projectContext/smart.md`
- **BigQuery Docs**: https://cloud.google.com/bigquery/docs
- **Looker Docs**: https://docs.looker.com

---

## ✅ Checklist de Implementación

### Fase 1: Validación (Esta semana)
- [ ] Verificar acceso a BigQuery
- [ ] Ejecutar query de prueba simple
- [ ] Ejecutar Query 01.1 con filtro específico
- [ ] Revisar bytes procesados y costos

### Fase 2: Dashboards Looker (Próxima semana)
- [ ] Configurar conexión BigQuery en Looker
- [ ] Crear vista LookML para Query 01.1
- [ ] Crear dashboard de degradación de neumáticos
- [ ] Agregar filtros interactivos

### Fase 3: Análisis Avanzado (Semana 3)
- [ ] Implementar Query 02.2 en Looker
- [ ] Crear dashboard de estrategias de pit stop
- [ ] Implementar Query 03.1 para correlaciones climáticas

### Fase 4: Productización (Semana 4)
- [ ] Ejecutar Query 04.4 para métricas de piloto
- [ ] Crear script ETL a DynamoDB
- [ ] Desplegar API Lambda para perfiles de piloto
- [ ] Testing de latencia (<200ms)

---

**¿Listo para empezar?**
1. Abre BigQuery Console
2. Copia Query 01.1 (degradación de neumáticos)
3. Agrega filtro: `WHERE EventDate = '2024-05-26'` (Mónaco)
4. Ejecuta y analiza resultados

**Siguiente paso**: Crear tu primer dashboard en Looker con los resultados

---

**Última actualización**: 2025-10-13
**Versión**: 1.0
