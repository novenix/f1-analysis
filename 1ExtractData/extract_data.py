# -*- coding: utf-8 -*-
"""
Extractor de Datos Granulares de Fórmula 1 (Versión Final)

Este script utiliza la librería FastF1 para recolectar datos detallados de
carreras de Fórmula 1 para un rango de años especificado (2021-2025).

Correcciones:
- Se añade la creación automática del directorio de caché.
- Se corrige el manejo de zonas horarias (timezone) al comparar fechas para
  filtrar eventos pasados.
"""
import fastf1
import pandas as pd
import logging
import os
from datetime import datetime

# --- Configuración ---
YEAR_START = 2021
YEAR_END = 2025 
OUTPUT_CSV_PATH = 'f1_master_data_2021-2025.csv'
CACHE_DIR = 'cache'

# Crear el directorio de caché si no existe
if not os.path.exists(CACHE_DIR):
    os.makedirs(CACHE_DIR)
    print(f"Directorio de caché '{CACHE_DIR}' creado exitosamente.")

fastf1.Cache.enable_cache(CACHE_DIR)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


def get_race_data(year, round_number, event_name):
    """
    Obtiene los datos detallados de vueltas para una carrera específica.
    """
    try:
        logging.info(f"Procesando: Año {year}, Ronda {round_number} - {event_name}")
        session = fastf1.get_session(year, round_number, 'R')
        session.load(laps=True, telemetry=False, weather=False, messages=False)
        
        laps_data = session.laps
        
        if laps_data is None or laps_data.empty:
            logging.warning(f"No se encontraron datos de vueltas para {event_name} {year}.")
            return None

        laps_data['Year'] = year
        laps_data['EventName'] = event_name
        laps_data['RoundNumber'] = round_number
        
        return laps_data

    except Exception as e:
        logging.error(f"No se pudo procesar {event_name} {year} (Ronda {round_number}). Razón: {e}")
        return None

def main():
    """
    Función principal para orquestar la extracción de datos.
    """
    logging.info("Iniciando la extracción de datos de F1...")
    all_races_data = []
    
    for year in range(YEAR_START, YEAR_END + 1):
        logging.info(f"--- Obteniendo calendario para el año {year} ---")
        try:
            schedule = fastf1.get_event_schedule(year, include_testing=False)
            
            # Definimos la fecha actual con zona horaria UTC
            today = pd.to_datetime('today').tz_localize('UTC')
            
            # --- SOLUCIÓN: Asignamos la zona horaria UTC a las fechas del calendario antes de comparar ---
            past_events = schedule[schedule['EventDate'].dt.tz_localize('UTC') < today]
            
            if past_events.empty:
                logging.info(f"No hay eventos pasados para el año {year}. Pasando al siguiente.")
                continue

            for _, event in past_events.iterrows():
                race_df = get_race_data(year, event['RoundNumber'], event['EventName'])
                if race_df is not None:
                    all_races_data.append(race_df)

        except Exception as e:
            logging.error(f"No se pudo obtener el calendario para el año {year}. Razón: {e}")

    if not all_races_data:
        logging.warning("No se recolectó ningún dato. Finalizando el script.")
        return

    logging.info("Consolidando todos los datos en un único DataFrame...")
    master_df = pd.concat(all_races_data, ignore_index=True)
    
    cols_to_move = ['Year', 'EventName', 'RoundNumber', 'Driver', 'Team', 'LapNumber', 'Stint', 'Compound', 'TyreLife', 'LapTime', 'Sector1Time', 'Sector2Time', 'Sector3Time', 'SpeedI1', 'SpeedI2', 'SpeedST']
    existing_cols_to_move = [col for col in cols_to_move if col in master_df.columns]
    other_cols = [col for col in master_df.columns if col not in existing_cols_to_move]
    master_df = master_df[existing_cols_to_move + other_cols]

    logging.info(f"Guardando los datos consolidados en: {OUTPUT_CSV_PATH}")
    master_df.to_csv(OUTPUT_CSV_PATH, index=False, encoding='utf-8')
    
    logging.info("¡Extracción de datos completada exitosamente!")
    logging.info(f"Se procesaron {len(master_df)} vueltas en total.")


if __name__ == "__main__":
    main()
