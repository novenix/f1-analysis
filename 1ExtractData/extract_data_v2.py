# -*- coding: utf-8 -*-
"""
Extractor Enfocado de Datos de Fórmula 1 (v3 - Sin Borrado de Caché)

Este script se centra en extraer la totalidad de los datos disponibles
únicamente para las sesiones de Carrera ('R') y Carrera Sprint ('S')
de cada evento de F1 en un rango de años especificado.

NUEVAS FUNCIONALIDADES (v3):
- Se ha eliminado por completo la función de limpieza de caché para evitar
  borrados accidentales de datos de eventos completos. El script ahora solo
  lee y escribe en la caché, sin borrar.
- Mantiene el manejo robusto de errores HTTP 500 y Rate Limits.
"""
import fastf1
import pandas as pd
import logging
import os
import time
import shutil
from requests.exceptions import HTTPError # Importar la excepción de error HTTP

# --- Configuración General ---
YEAR_START = 2021
YEAR_END = 2025
CACHE_DIR = 'cache'
OUTPUT_DIR = 'f1_data_lake_focused'

SESSION_IDENTIFIERS_TO_FETCH = ['R', 'S'] 

# --- Configuración de Reintentos para la API ---
MAX_RETRIES = 5
INITIAL_RETRY_DELAY = 60

# --- Setup Inicial ---
if not os.path.exists(CACHE_DIR): os.makedirs(CACHE_DIR)
if not os.path.exists(OUTPUT_DIR): os.makedirs(OUTPUT_DIR)

fastf1.Cache.enable_cache(CACHE_DIR)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- FUNCIÓN DE LIMPIEZA ELIMINADA ---

def process_session_data(session):
    # (Esta función no cambia)
    session_data = { 'results': None, 'weather': None, 'race_control': None, 'laps': None, 'telemetry': None }
    try:
        results = session.results
        if results is not None and not results.empty:
            results['Year'] = session.event['EventDate'].year
            results['EventName'] = session.event['EventName']
            results['SessionName'] = session.name
            session_data['results'] = results
    except Exception as e:
        logging.warning(f"No se pudieron cargar los resultados para {session.event['EventName']} {session.name}: {e}")

    if not session.weather_data.empty:
        weather = session.weather_data
        weather['Year'] = session.event['EventDate'].year
        weather['EventName'] = session.event['EventName']
        weather['SessionName'] = session.name
        session_data['weather'] = weather

    if not session.race_control_messages.empty:
        rcm = session.race_control_messages
        rcm['Year'] = session.event['EventDate'].year
        rcm['EventName'] = session.event['EventName']
        rcm['SessionName'] = session.name
        session_data['race_control'] = rcm
        
    if not session.laps.empty:
        laps = session.laps
        laps['Year'] = session.event['EventDate'].year
        laps['EventName'] = session.event['EventName']
        laps['SessionName'] = session.name
        session_data['laps'] = laps

        all_telemetry = []
        logging.info("Extrayendo telemetría vuelta por vuelta...")
        for lap in laps.iterlaps():
            try:
                telemetry = lap.get_telemetry()
                if not telemetry.empty:
                    telemetry['Driver'] = lap['Driver']
                    telemetry['LapNumber'] = lap['LapNumber']
                    telemetry['Year'] = session.event['EventDate'].year
                    telemetry['EventName'] = session.event['EventName']
                    telemetry['SessionName'] = session.name
                    all_telemetry.append(telemetry)
            except Exception as e:
                logging.warning(f"No se pudo obtener telemetría para la vuelta {lap['LapNumber']} de {lap['Driver']}: {e}")
        
        if all_telemetry:
            session_data['telemetry'] = pd.concat(all_telemetry, ignore_index=True)

    return session_data


def main():
    # --- LLAMADA A LA FUNCIÓN DE LIMPIEZA ELIMINADA DE AQUÍ ---
    logging.info("INICIO DEL PROCESO DE EXTRACCIÓN ENFOCADA (Race & Sprint)")
    
    all_data_lists = { 'events': [], 'sessions': [], 'results': [], 'weather': [], 'race_control': [], 'laps': [], 'telemetry': [] }
    
    for year in range(YEAR_START, YEAR_END + 1):
        logging.info(f"--- PROCESANDO AÑO {year} ---")
        try:
            schedule = fastf1.get_event_schedule(year, include_testing=False)
            today = pd.to_datetime('today').tz_localize('UTC')
            past_events = schedule[schedule['EventDate'].dt.tz_localize('UTC') < today]
            all_data_lists['events'].append(schedule)

            for _, event in past_events.iterrows():
                logging.info(f"== Evento: {event['EventName']} ==")
                
                for session_name in SESSION_IDENTIFIERS_TO_FETCH:
                    retries = 0
                    delay = INITIAL_RETRY_DELAY
                    
                    while retries < MAX_RETRIES:
                        try:
                            session = fastf1.get_session(year, event['RoundNumber'], session_name)
                            session.load(laps=True, telemetry=True, weather=True, messages=True)
                            
                            logging.info(f"Cargando datos para la sesión: {session.name}")
                            all_data_lists['sessions'].append({'Year': year, 'EventName': event['EventName'], 'SessionName': session.name, 'SessionDate': session.date})

                            data = process_session_data(session)

                            if data['results'] is not None: all_data_lists['results'].append(data['results'])
                            if data['weather'] is not None: all_data_lists['weather'].append(data['weather'])
                            if data['race_control'] is not None: all_data_lists['race_control'].append(data['race_control'])
                            if data['laps'] is not None: all_data_lists['laps'].append(data['laps'])
                            if data['telemetry'] is not None: all_data_lists['telemetry'].append(data['telemetry'])
                            
                            break 
                        
                        except (fastf1.req.RateLimitExceededError, HTTPError) as e:
                            logging.warning(f"Error de API (Rate Limit o Error 500 detectado). Esperando {delay} segundos antes de reintentar...")
                            time.sleep(delay)
                            retries += 1
                            delay *= 2 
                        except Exception as e:
                            logging.warning(f"No se pudo cargar la sesión '{session_name}' para {event['EventName']} {year} (puede que no exista). Razón: {e}")
                            break
                            
        except Exception as e:
            logging.error(f"FALLO CRÍTICO al procesar el año {year}. Razón: {e}")
            
    logging.info("--- PROCESO DE GUARDADO EN ARCHIVOS CSV ---")
    
    def save_to_csv(data_list, filename):
        if data_list:
            full_path = os.path.join(OUTPUT_DIR, filename)
            logging.info(f"Guardando datos en {full_path}...")
            df = pd.concat(data_list, ignore_index=True)
            df.to_csv(full_path, index=False, encoding='utf-8')
            logging.info(f"Guardado exitoso. Total de filas: {len(df)}")
        else:
            logging.warning(f"No se encontraron datos para guardar en {filename}.")
            
    save_to_csv(all_data_lists['events'], 'events.csv')
    if all_data_lists['sessions']:
        sessions_df = pd.DataFrame(all_data_lists['sessions'])
        sessions_df.to_csv(os.path.join(OUTPUT_DIR, 'sessions.csv'), index=False, encoding='utf-8')

    save_to_csv(all_data_lists['results'], 'results.csv')
    save_to_csv(all_data_lists['weather'], 'weather.csv')
    save_to_csv(all_data_lists['race_control'], 'race_control.csv')
    save_to_csv(all_data_lists['laps'], 'laps.csv')
    save_to_csv(all_data_lists['telemetry'], 'telemetry.csv')

    logging.info("¡PROCESO DE EXTRACCIÓN ENFOCADA COMPLETADO!")

if __name__ == "__main__":
    main()

