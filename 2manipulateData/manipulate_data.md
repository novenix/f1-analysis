# Enriquecimiento de Datos de Laps con Telemetría por Sector

## Objetivo
Consolidar datos de telemetría agregados por sector en los archivos de laps existentes, creando archivos enriquecidos (`laps_año_enriched.csv`) que combinen los datos de timing con métricas detalladas de telemetría por sector.

## Estructura de Datos

### Datos de Entrada
1. **Laps Base** (`f1_data_lake_focused/año/laps_año.csv`):
   - Consolidado de todos los circuitos y pilotos por año
   - Campos clave: `Sector1SessionTime`, `Sector2SessionTime`, `Sector3SessionTime`
   - Estructura actual: `Time,Driver,DriverNumber,LapTime,LapNumber,Stint,PitOutTime,PitInTime,Sector1Time,Sector2Time,Sector3Time,Sector1SessionTime,Sector2SessionTime,Sector3SessionTime,SpeedI1,SpeedI2,SpeedFL,SpeedST,IsPersonalBest,Compound,TyreLife,FreshTyre,Team,LapStartTime,LapStartDate,TrackStatus,Position,Deleted,DeletedReason,FastF1Generated,IsAccurate,Year,EventName,SessionName`

2. **Telemetría** (`f1_telemetry_data/año/circuito/telemetry_PILOTO.csv`):
   - Datos por milisegundos por piloto y circuito
   - Campos: `Date,SessionTime,DriverAhead,DistanceToDriverAhead,Time,RPM,Speed,nGear,Throttle,Brake,DRS,Source,Distance,RelativeDistance,Status,X,Y,Z,LapNumber`

### Segmentación por Sector
Usar `SessionTime` de telemetría para mapear con los timestamps de sector:
- **Sector 1**: Desde inicio de vuelta hasta `Sector1SessionTime`
- **Sector 2**: Desde `Sector1SessionTime` hasta `Sector2SessionTime`
- **Sector 3**: Desde `Sector2SessionTime` hasta fin de vuelta

## Métricas a Agregar por Sector

### Promedios
- `SectorX_RPM_Avg`: RPM promedio
- `SectorX_Throttle_Avg`: Throttle promedio (%)
- `SectorX_Speed_Avg`: Velocidad promedio

### Máximos
- `SectorX_Speed_Max`: Velocidad máxima
- `SectorX_nGear_Max`: Marcha más alta utilizada

### Mínimos
- `SectorX_Speed_Min`: Velocidad mínima
- `SectorX_nGear_Min`: Marcha más baja utilizada

### Modas
- `SectorX_nGear_Mode`: Marcha más frecuentemente utilizada

### Valores Específicos
- `SectorX_DRS_Percentage`: % del tiempo con DRS activado
- `SectorX_Status_Mode`: Estado más frecuente

### Métricas Derivadas
- `SectorX_Throttle_100_Time`: Tiempo en aceleración completa (Throttle = 100%)
- `SectorX_Brake_Time`: Tiempo frenando (Brake = True)
- `SectorX_Throttle_Time`: Tiempo total acelerando (Throttle > 0%)
- `SectorX_Coasting_Time`: Tiempo sin acelerar ni frenar
- `SectorX_Gear_Changes`: Número de cambios de marcha
- `SectorX_Speed_StdDev`: Variabilidad de velocidad (desviación estándar)
- `SectorX_Distance_Sector`: Distancia recorrida en el sector

## Resultado Final
- **Archivo de salida**: `laps_año_enriched.csv`
- **Nuevas columnas**: ~39 columnas adicionales (13 métricas × 3 sectores)
- **Ubicación**: `f1_data_lake_focused/año/laps_año_enriched.csv`

## Proceso de Consolidación
1. Leer archivo de laps base por año
2. Para cada vuelta (por piloto, circuito, lap number):
   - Cargar telemetría correspondiente del piloto y circuito
   - Filtrar telemetría por `LapNumber`
   - Segmentar por sectores usando `SessionTime`
   - Calcular métricas agregadas por sector
   - Agregar columnas al registro de lap
3. Guardar archivo enriquecido

## Validación
- Verificar que `Distance_Sector` sumado por los 3 sectores sea consistente
- Validar que los timestamps de telemetría estén dentro de los rangos de sector
- Comparar métricas calculadas con datos base existentes (ej: velocidades)