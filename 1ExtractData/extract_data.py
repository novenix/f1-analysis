# -*- coding: utf-8 -*-
"""
Extractor de Datos Granulares de Fórmula 1 (Versión Robusta)

Este script utiliza la librería FastF1 para recolectar datos detallados de
carreras de Fórmula 1 para un rango de años especificado (2021-2025).

Correcciones:
- Se añade la creación automática del directorio de caché.
- Se corrige el manejo de zonas horarias (timezone).
- Se reemplaza la pausa fija por un mecanismo inteligente de reintentos
  automáticos con espera exponencial solo cuando se detecta un error de
  límite de peticiones (Rate Limit).
"""
import fastf1
import pandas as pd
import logging
import os
import time

# --- Configuración ---
YEAR_START = 2021
YEAR_END = 2025 
OUTPUT_CSV_PATH = 'f1_master_data_2021-2025.csv'
CACHE_DIR = 'cache'
MAX_RETRIES = 5  # Número máximo de reintentos para una carrera antes de rendirse
INITIAL_RETRY_DELAY = 60  # Pausa inicial en segundos después de un error de rate limit

# Crear el directorio de caché si no existe
if not os.path.exists(CACHE_DIR):
    os.makedirs(CACHE_DIR)
    print(f"Directorio de caché '{CACHE_DIR}' creado exitosamente.")

fastf1.Cache.enable_cache(CACHE_DIR)

# Configurar logging para mostrar mensajes de info y errores.
# Cambiar a logging.DEBUG para ver más detalles si es necesario.
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


def get_race_data_with_retries(year, round_number, event_name):
    """
    Obtiene los datos de una carrera con una lógica de reintentos para manejar
    los errores de límite de peticiones de la API (Rate Limit).
    """
    retries = 0
    delay = INITIAL_RETRY_DELAY
    while retries < MAX_RETRIES:
        try:
            logging.info(f"Procesando: Año {year}, Ronda {round_number} - {event_name} (Intento {retries + 1})")
            session = fastf1.get_session(year, round_number, 'R')
            session.load(laps=True, telemetry=False, weather=False, messages=False)
            
            laps_data = session.laps
            
            if laps_data is None or laps_data.empty:
                logging.warning(f"No se encontraron datos de vueltas para {event_name} {year}.")
                return None

            laps_data['Year'] = year
            laps_data['EventName'] = event_name
            laps_data['RoundNumber'] = round_number
            
            return laps_data # Si todo sale bien, retornamos los datos

        except fastf1.req.RateLimitExceededError as e:
            logging.warning(f"Límite de la API alcanzado. Esperando {delay} segundos antes de reintentar...")
            time.sleep(delay)
            retries += 1
            delay *= 2 # Backoff exponencial: duplicamos la espera en el siguiente reintento
        
        except Exception as e:
            if "The data you are trying to access has not been loaded yet" in str(e):
                logging.error(f"Error al procesar {event_name} {year}. Datos incompletos, probablemente por un 'Rate Limit' anterior.")
            else:
                logging.error(f"No se pudo procesar {event_name} {year} (Ronda {round_number}). Razón: {e}")
            return None # Si el error no es de Rate Limit, no reintentamos

    logging.error(f"Se superó el número máximo de reintentos ({MAX_RETRIES}) para {event_name} {year}. Pasando al siguiente.")
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
            today = pd.to_datetime('today').tz_localize('UTC')
            past_events = schedule[schedule['EventDate'].dt.tz_localize('UTC') < today]
            
            if past_events.empty:
                logging.info(f"No hay eventos pasados para el año {year}. Pasando al siguiente.")
                continue

            for _, event in past_events.iterrows():
                # Llamamos a la nueva función con lógica de reintentos
                race_df = get_race_data_with_retries(year, event['RoundNumber'], event['EventName'])
                
                if race_df is not None:
                    all_races_data.append(race_df)

        except Exception as e:
            logging.error(f"No se pudo obtener el calendario para el año {year}. Razón: {e}")

    if not all_races_data:
        logging.warning("No se recolectó ningún dato nuevo en esta ejecución. Finalizando el script.")
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
    logging.info(f"El archivo CSV ahora contiene un total de {len(master_df)} vueltas.")


if __name__ == "__main__":
    main()

