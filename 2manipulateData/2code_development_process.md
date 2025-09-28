# Proceso de Desarrollo del Código de Enriquecimiento

## Algoritmo de Cálculo de Sectores

### Datos de Entrada Necesarios
Para cada vuelta (lap) necesitamos:
1. **Del archivo laps**: `Sector1SessionTime`, `Sector2SessionTime`, `Sector3SessionTime`
2. **Del archivo telemetría**: Datos filtrados por `LapNumber` correspondiente

### Determinación de Rangos de Tiempo por Sector

#### Cálculo de Timestamps de Inicio y Fin
```python
# Para cada vuelta - PRIMERO filtrar por LapNumber específico
lap_telemetry = telemetry_data[telemetry_data['LapNumber'] == current_lap_number]

lap_start_time = lap_telemetry['SessionTime'].min()  # Primer timestamp de ESTA vuelta
lap_end_time = lap_telemetry['SessionTime'].max()    # Último timestamp de ESTA vuelta

# Rangos por sector
sector1_start = lap_start_time
sector1_end = lap_data['Sector1SessionTime']

sector2_start = lap_data['Sector1SessionTime']
sector2_end = lap_data['Sector2SessionTime']

sector3_start = lap_data['Sector2SessionTime']
sector3_end = lap_end_time
```

### Filtrado de Telemetría por Sector
```python
# Filtrar datos de telemetría para cada sector (ya filtrada por LapNumber)
sector1_telemetry = lap_telemetry[
    (lap_telemetry['SessionTime'] >= sector1_start) &
    (lap_telemetry['SessionTime'] < sector1_end)
]

sector2_telemetry = lap_telemetry[
    (lap_telemetry['SessionTime'] >= sector2_start) &
    (lap_telemetry['SessionTime'] < sector2_end)
]

sector3_telemetry = lap_telemetry[
    (lap_telemetry['SessionTime'] >= sector3_start) &
    (lap_telemetry['SessionTime'] <= sector3_end)
]
```

## Cálculo de Métricas por Sector

### Métricas Básicas (Promedio, Max, Min)
```python
def calculate_basic_metrics(sector_data):
    return {
        'RPM_Avg': sector_data['RPM'].mean(),
        'Throttle_Avg': sector_data['Throttle'].mean(),
        'Speed_Avg': sector_data['Speed'].mean(),
        'Speed_Max': sector_data['Speed'].max(),
        'Speed_Min': sector_data['Speed'].min(),
        'nGear_Max': sector_data['nGear'].max(),
        'nGear_Min': sector_data['nGear'].min(),
        'Speed_StdDev': sector_data['Speed'].std()
    }
```

### Métricas de Moda
```python
def calculate_mode_metrics(sector_data):
    return {
        'nGear_Mode': sector_data['nGear'].mode().iloc[0] if not sector_data['nGear'].mode().empty else None,
        'Status_Mode': sector_data['Status'].mode().iloc[0] if not sector_data['Status'].mode().empty else None
    }
```

### Métricas Derivadas (Tiempo y Conteos)
```python
def calculate_derived_metrics(sector_data):
    # Frecuencia de muestreo aproximada (tiempo entre mediciones)
    time_diff = sector_data['SessionTime'].diff().mean()  # En segundos

    return {
        'Throttle_100_Time': len(sector_data[sector_data['Throttle'] == 100]) * time_diff,
        'Brake_Time': len(sector_data[sector_data['Brake'] == True]) * time_diff,
        'Throttle_Time': len(sector_data[sector_data['Throttle'] > 0]) * time_diff,
        'Coasting_Time': len(sector_data[(sector_data['Throttle'] == 0) & (sector_data['Brake'] == False)]) * time_diff,
        'DRS_Percentage': (len(sector_data[sector_data['DRS'] > 0]) / len(sector_data)) * 100 if len(sector_data) > 0 else 0,
        'Gear_Changes': (sector_data['nGear'].diff() != 0).sum(),
        'Distance_Sector': sector_data['Distance'].max() - sector_data['Distance'].min() if len(sector_data) > 0 else 0
    }
```

## Estructura del Proceso Principal

### 1. Carga de Datos
```python
def load_data(year):
    # Cargar laps base
    laps_df = pd.read_csv(f'f1_data_lake_focused/{year}/laps_{year}.csv')

    # Obtener lista de eventos únicos
    events = laps_df['EventName'].unique()

    return laps_df, events
```

### 2. Procesamiento por Vuelta
```python
def process_lap(lap_row, telemetry_data):
    # Filtrar telemetría para esta vuelta específica
    lap_telemetry = telemetry_data[telemetry_data['LapNumber'] == lap_row['LapNumber']]

    # Calcular métricas para cada sector
    enriched_data = {}

    for sector_num in [1, 2, 3]:
        sector_data = filter_sector_telemetry(lap_telemetry, lap_row, sector_num)

        basic_metrics = calculate_basic_metrics(sector_data)
        mode_metrics = calculate_mode_metrics(sector_data)
        derived_metrics = calculate_derived_metrics(sector_data)

        # Agregar prefijo de sector a las métricas
        for metric, value in {**basic_metrics, **mode_metrics, **derived_metrics}.items():
            enriched_data[f'Sector{sector_num}_{metric}'] = value

    return enriched_data
```

### 3. Validaciones
```python
def validate_sector_data(sector_data, lap_data, sector_num):
    # Validar que hay datos en el sector
    if len(sector_data) == 0:
        logging.warning(f"No telemetry data for Sector {sector_num}")
        return False

    # Validar rangos de tiempo
    expected_duration = get_expected_sector_duration(lap_data, sector_num)
    actual_duration = sector_data['SessionTime'].max() - sector_data['SessionTime'].min()

    if abs(expected_duration - actual_duration) > 5:  # Tolerancia de 5 segundos
        logging.warning(f"Time mismatch in Sector {sector_num}: expected {expected_duration}, got {actual_duration}")

    return True
```

## Manejo de Casos Especiales

### Datos Faltantes
- Si no hay telemetría para un sector: llenar con `None` o `-1`
- Si faltan timestamps de sector: usar inicio/fin de vuelta como fallback
- Logging detallado de datos faltantes para análisis posterior

### Optimización de Performance
- Cargar telemetría por evento (no por vuelta individual)
- Usar indexación por `LapNumber` para filtrado rápido
- Procesar en chunks para manejar memoria
- Paralelización por evento si es necesario