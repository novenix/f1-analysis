# -*- coding: utf-8 -*-
"""
Enriquecimiento de Datos de Laps con Telemetría por Sector (v1.0)

Este script enriquece los archivos de laps con métricas agregadas de telemetría
por sector para un AÑO ESPECÍFICO.

FUNCIONALIDADES:
- Carga datos de laps base desde f1_data_lake_focused/año/laps_año.csv
- Carga telemetría correspondiente desde f1_telemetry_data/año/circuito/
- Calcula 13 métricas por sector (39 columnas adicionales)
- Genera archivo enriquecido: laps_año_enriched.csv
- Logging detallado del proceso y errores
"""

import pandas as pd
import numpy as np
import logging
import os
import argparse
import glob

# --- Configuración de Directorios ---
DATA_LAKE_DIR = 'f1_data_lake_focused'
TELEMETRY_DIR = 'f1_telemetry_data'

def setup_logging(year):
    """Configurar logging específico para el año."""
    logging.basicConfig(
        level=logging.INFO,  # Volver a INFO
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(f'telemetry_enrichment_{year}.log'),
            logging.StreamHandler()
        ]
    )

def load_laps_data(year):
    """Cargar datos base de laps para el año especificado."""
    laps_file = os.path.join(DATA_LAKE_DIR, str(year), f'laps_{year}.csv')

    if not os.path.exists(laps_file):
        raise FileNotFoundError(f"No se encontró el archivo de laps: {laps_file}")

    laps_df = pd.read_csv(laps_file)

    # Convertir timestamps de sector a timedelta para consistencia con telemetría
    timestamp_columns = ['Sector1SessionTime', 'Sector2SessionTime', 'Sector3SessionTime']
    for col in timestamp_columns:
        if col in laps_df.columns:
            if laps_df[col].dtype == 'object':
                laps_df[col] = pd.to_timedelta(laps_df[col], errors='coerce')
            else:
                laps_df[col] = pd.to_numeric(laps_df[col], errors='coerce')

    events = laps_df['EventName'].unique()

    logging.info(f"Cargado archivo de laps: {laps_file}")
    logging.info(f"Total de vueltas: {len(laps_df)}")
    logging.info(f"Eventos encontrados: {len(events)}")

    return laps_df, events

def load_telemetry_data(year, event_name):
    """Cargar todos los archivos de telemetría para un evento específico."""
    # Convertir nombre del evento a formato de directorio
    event_dir = event_name.replace(' ', '_')
    telemetry_path = os.path.join(TELEMETRY_DIR, str(year), event_dir)

    if not os.path.exists(telemetry_path):
        logging.warning(f"Directorio de telemetría no encontrado: {telemetry_path}")
        return {}

    telemetry_files = glob.glob(os.path.join(telemetry_path, 'telemetry_*.csv'))
    telemetry_data = {}

    for file_path in telemetry_files:
        # Extraer código del piloto del nombre del archivo
        driver_code = os.path.basename(file_path).replace('telemetry_', '').replace('.csv', '')

        try:
            df = pd.read_csv(file_path)

            # Convertir SessionTime a formato timedelta si es necesario
            if df['SessionTime'].dtype == 'object':
                # Si es string como "0 days 00:37:09.970000", convertir a timedelta
                df['SessionTime'] = pd.to_timedelta(df['SessionTime'], errors='coerce')

            # Convertir LapNumber a float para consistencia
            df['LapNumber'] = pd.to_numeric(df['LapNumber'], errors='coerce')

            telemetry_data[driver_code] = df
            logging.info(f"Cargada telemetría para {driver_code} en {event_name}: {len(df)} puntos de datos")
            logging.debug(f"DEBUG - {driver_code}: LapNumbers únicos = {sorted(df['LapNumber'].unique())}")

        except Exception as e:
            logging.error(f"Error cargando telemetría para {driver_code}: {e}")

    return telemetry_data

def calculate_basic_metrics(sector_data):
    """Calcular métricas básicas (promedio, max, min) para un sector."""
    if len(sector_data) == 0:
        return {
            'RPM_Avg': None, 'Throttle_Avg': None, 'Speed_Avg': None,
            'Speed_Max': None, 'Speed_Min': None, 'nGear_Max': None,
            'nGear_Min': None, 'Speed_StdDev': None
        }

    return {
        'RPM_Avg': sector_data['RPM'].mean() if 'RPM' in sector_data.columns else None,
        'Throttle_Avg': sector_data['Throttle'].mean() if 'Throttle' in sector_data.columns else None,
        'Speed_Avg': sector_data['Speed'].mean() if 'Speed' in sector_data.columns else None,
        'Speed_Max': sector_data['Speed'].max() if 'Speed' in sector_data.columns else None,
        'Speed_Min': sector_data['Speed'].min() if 'Speed' in sector_data.columns else None,
        'nGear_Max': sector_data['nGear'].max() if 'nGear' in sector_data.columns else None,
        'nGear_Min': sector_data['nGear'].min() if 'nGear' in sector_data.columns else None,
        'Speed_StdDev': sector_data['Speed'].std() if 'Speed' in sector_data.columns else None
    }

def calculate_mode_metrics(sector_data):
    """Calcular métricas de moda para un sector."""
    if len(sector_data) == 0:
        return {'nGear_Mode': None, 'Status_Mode': None}

    result = {}

    # nGear Mode - usar pandas mode() en lugar de scipy.stats.mode()
    if 'nGear' in sector_data.columns and not sector_data['nGear'].empty:
        gear_mode = sector_data['nGear'].dropna().mode()
        result['nGear_Mode'] = gear_mode.iloc[0] if len(gear_mode) > 0 else None
    else:
        result['nGear_Mode'] = None

    # Status Mode - usar pandas mode() en lugar de scipy.stats.mode()
    if 'Status' in sector_data.columns and not sector_data['Status'].empty:
        status_mode = sector_data['Status'].dropna().mode()
        result['Status_Mode'] = status_mode.iloc[0] if len(status_mode) > 0 else None
    else:
        result['Status_Mode'] = None

    return result

def calculate_derived_metrics(sector_data):
    """Calcular métricas derivadas (tiempo y conteos) para un sector."""
    if len(sector_data) == 0:
        return {
            'Throttle_100_Time': None, 'Brake_Time': None, 'Throttle_Time': None,
            'Coasting_Time': None, 'DRS_Percentage': None, 'Gear_Changes': None,
            'Distance_Sector': None
        }

    # Calcular frecuencia de muestreo (tiempo entre mediciones)
    if len(sector_data) > 1:
        time_diff = sector_data['SessionTime'].diff().mean()
    else:
        time_diff = 0.05  # Fallback: 50ms aproximadamente

    result = {}

    # Throttle 100% Time
    if 'Throttle' in sector_data.columns:
        throttle_100_count = len(sector_data[sector_data['Throttle'] == 100])
        result['Throttle_100_Time'] = throttle_100_count * time_diff
    else:
        result['Throttle_100_Time'] = None

    # Brake Time
    if 'Brake' in sector_data.columns:
        brake_count = len(sector_data[sector_data['Brake'] == True])
        result['Brake_Time'] = brake_count * time_diff
    else:
        result['Brake_Time'] = None

    # Throttle Time (> 0%)
    if 'Throttle' in sector_data.columns:
        throttle_count = len(sector_data[sector_data['Throttle'] > 0])
        result['Throttle_Time'] = throttle_count * time_diff
    else:
        result['Throttle_Time'] = None

    # Coasting Time (no acelerar ni frenar)
    if 'Throttle' in sector_data.columns and 'Brake' in sector_data.columns:
        coasting_count = len(sector_data[(sector_data['Throttle'] == 0) & (sector_data['Brake'] == False)])
        result['Coasting_Time'] = coasting_count * time_diff
    else:
        result['Coasting_Time'] = None

    # DRS Percentage
    if 'DRS' in sector_data.columns:
        drs_count = len(sector_data[sector_data['DRS'] > 0])
        result['DRS_Percentage'] = (drs_count / len(sector_data)) * 100 if len(sector_data) > 0 else 0
    else:
        result['DRS_Percentage'] = None

    # Gear Changes
    if 'nGear' in sector_data.columns and len(sector_data) > 1:
        gear_changes = (sector_data['nGear'].diff() != 0).sum()
        result['Gear_Changes'] = gear_changes
    else:
        result['Gear_Changes'] = None

    # Distance Sector
    if 'Distance' in sector_data.columns and len(sector_data) > 0:
        result['Distance_Sector'] = sector_data['Distance'].max() - sector_data['Distance'].min()
    else:
        result['Distance_Sector'] = None

    return result

def filter_sector_telemetry(lap_telemetry, lap_row, sector_num):
    """Filtrar telemetría para un sector específico usando timestamps."""
    if len(lap_telemetry) == 0:
        return pd.DataFrame()

    lap_start_time = lap_telemetry['SessionTime'].min()
    lap_end_time = lap_telemetry['SessionTime'].max()

    # Obtener timestamps de sector
    if sector_num == 1:
        sector_start = lap_start_time
        sector_end = lap_row['Sector1SessionTime'] if pd.notna(lap_row['Sector1SessionTime']) else lap_end_time
    elif sector_num == 2:
        sector_start = lap_row['Sector1SessionTime'] if pd.notna(lap_row['Sector1SessionTime']) else lap_start_time
        sector_end = lap_row['Sector2SessionTime'] if pd.notna(lap_row['Sector2SessionTime']) else lap_end_time
    else:  # sector_num == 3
        sector_start = lap_row['Sector2SessionTime'] if pd.notna(lap_row['Sector2SessionTime']) else lap_start_time
        sector_end = lap_end_time

    # Filtrar telemetría por rango de tiempo
    if sector_num == 3:
        sector_telemetry = lap_telemetry[
            (lap_telemetry['SessionTime'] >= sector_start) &
            (lap_telemetry['SessionTime'] <= sector_end)
        ]
    else:
        sector_telemetry = lap_telemetry[
            (lap_telemetry['SessionTime'] >= sector_start) &
            (lap_telemetry['SessionTime'] < sector_end)
        ]

    return sector_telemetry

def process_lap(lap_row, telemetry_data):
    """Procesar una vuelta específica y calcular métricas por sector."""
    driver = lap_row['Driver']
    lap_number = lap_row['LapNumber']
    event_name = lap_row['EventName']

    # Verificar si tenemos telemetría para este piloto
    if driver not in telemetry_data:
        logging.warning(f"No telemetría para {driver} en {event_name}")
        return create_empty_metrics()

    # Filtrar telemetría para esta vuelta específica
    driver_telemetry = telemetry_data[driver]

    # DEBUG: Verificar qué LapNumbers tenemos disponibles
    available_laps = driver_telemetry['LapNumber'].unique()
    logging.debug(f"DEBUG - {driver} vuelta {lap_number}: LapNumbers disponibles = {available_laps[:10]}...")

    lap_telemetry = driver_telemetry[driver_telemetry['LapNumber'] == lap_number]

    if len(lap_telemetry) == 0:
        logging.warning(f"No telemetría para {driver} en vuelta {lap_number} de {event_name}")
        logging.debug(f"DEBUG - Buscando vuelta {lap_number} (tipo: {type(lap_number)})")
        return create_empty_metrics()

    # DEBUG: Info de la vuelta encontrada
    logging.debug(f"DEBUG - {driver} vuelta {lap_number}: {len(lap_telemetry)} puntos de telemetría encontrados")

    enriched_data = {}

    # Calcular métricas para cada sector
    for sector_num in [1, 2, 3]:
        sector_data = filter_sector_telemetry(lap_telemetry, lap_row, sector_num)

        if len(sector_data) == 0:
            logging.warning(f"No datos de telemetría para Sector {sector_num} - {driver} - Vuelta {lap_number} - {event_name}")

        # Calcular todas las métricas
        basic_metrics = calculate_basic_metrics(sector_data)
        mode_metrics = calculate_mode_metrics(sector_data)
        derived_metrics = calculate_derived_metrics(sector_data)

        # Agregar prefijo de sector a las métricas
        for metric, value in {**basic_metrics, **mode_metrics, **derived_metrics}.items():
            enriched_data[f'Sector{sector_num}_{metric}'] = value

    return enriched_data

def create_empty_metrics():
    """Crear métricas vacías cuando no hay datos de telemetría."""
    metrics = ['RPM_Avg', 'Throttle_Avg', 'Speed_Avg', 'Speed_Max', 'Speed_Min',
               'nGear_Max', 'nGear_Min', 'Speed_StdDev', 'nGear_Mode', 'Status_Mode',
               'Throttle_100_Time', 'Brake_Time', 'Throttle_Time', 'Coasting_Time',
               'DRS_Percentage', 'Gear_Changes', 'Distance_Sector']

    empty_data = {}
    for sector_num in [1, 2, 3]:
        for metric in metrics:
            empty_data[f'Sector{sector_num}_{metric}'] = None

    return empty_data

def process_event(laps_df, event_name, year, telemetry_data):
    """Procesar todas las vueltas de un evento específico."""
    logging.info(f"== Procesando evento: {event_name} ==")

    # Filtrar vueltas de este evento
    event_laps = laps_df[laps_df['EventName'] == event_name].copy()

    if len(event_laps) == 0:
        logging.warning(f"No se encontraron vueltas para el evento: {event_name}")
        return []

    enriched_laps = []

    for idx, lap_row in event_laps.iterrows():
        # Procesar la vuelta y obtener métricas enriquecidas
        enriched_metrics = process_lap(lap_row, telemetry_data)

        # Combinar datos originales con métricas enriquecidas
        enriched_lap = {**lap_row.to_dict(), **enriched_metrics}
        enriched_laps.append(enriched_lap)

        if idx % 100 == 0:  # Log cada 100 vueltas
            logging.info(f"Procesadas {idx + 1}/{len(event_laps)} vueltas de {event_name}")

    logging.info(f"Evento {event_name} completado. Total vueltas procesadas: {len(enriched_laps)}")
    return enriched_laps

def save_enriched_data(enriched_laps, year):
    """Guardar datos enriquecidos en archivo CSV."""
    if not enriched_laps:
        logging.warning("No hay datos enriquecidos para guardar")
        return

    # Crear DataFrame con todos los datos enriquecidos
    enriched_df = pd.DataFrame(enriched_laps)

    # Crear directorio de salida si no existe
    output_dir = os.path.join(DATA_LAKE_DIR, str(year))
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Guardar archivo enriquecido
    output_file = os.path.join(output_dir, f'laps_{year}_enriched.csv')
    enriched_df.to_csv(output_file, index=False, encoding='utf-8')

    logging.info(f"Archivo enriquecido guardado: {output_file}")
    logging.info(f"Total de vueltas: {len(enriched_df)}")
    logging.info(f"Total de columnas: {len(enriched_df.columns)}")

def main(year):
    """Función principal para enriquecer datos de laps con telemetría por año específico."""

    # Configurar logging específico para el año
    setup_logging(year)

    logging.info(f"--- INICIO DEL ENRIQUECIMIENTO DE TELEMETRÍA PARA EL AÑO {year} ---")

    try:
        # Cargar datos base de laps
        laps_df, events = load_laps_data(year)

        # Procesar cada evento
        all_enriched_laps = []

        for event_name in events:
            # Cargar telemetría para este evento
            telemetry_data = load_telemetry_data(year, event_name)

            # Procesar vueltas del evento
            event_enriched_laps = process_event(laps_df, event_name, year, telemetry_data)
            all_enriched_laps.extend(event_enriched_laps)

        # Guardar todos los datos enriquecidos
        save_enriched_data(all_enriched_laps, year)

        logging.info(f"¡ENRIQUECIMIENTO PARA EL AÑO {year} COMPLETADO!")

    except Exception as e:
        logging.error(f"FALLO CRÍTICO en el enriquecimiento del año {year}: {e}")
        raise

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Enriquecer datos de laps con telemetría por año específico")
    parser.add_argument("year", type=int, help="Año para procesar (ej: 2021, 2022, 2023)")
    args = parser.parse_args()

    main(args.year)