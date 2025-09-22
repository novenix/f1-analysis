# -*- coding: utf-8 -*-
"""
Extractor de Datos de Fórmula 1 por Año (v11 - Corrección de Compatibilidad)

Este script extrae datos para un AÑO ESPECÍFICO.

NUEVAS FUNCIONALIDADES (v11):
- Se eliminó el argumento 'timeout' de la función session.load() para
  asegurar la compatibilidad con versiones anteriores de la librería FastF1.
- Se mantiene la lógica robusta de verificación de tipos de datos para
  prevenir el error 'tuple indices...' y maximizar la extracción de datos.
"""
import fastf1
import pandas as pd
import logging
import os
import time
import argparse
from requests.exceptions import HTTPError
from fastf1.req import RateLimitExceededError

# --- Configuración General ---
CACHE_DIR = 'cache'
OUTPUT_DIR = 'f1_data_lake_focused'
SESSION_IDENTIFIERS_TO_FETCH = ['R', 'S']

# --- Configuración de Reintentos para la API ---
MAX_RETRIES = 5
INITIAL_RETRY_DELAY = 60
RATE_LIMIT_INCREMENT = 10
HTTP_ERROR_DELAY = 60

# --- Setup Inicial de Logging y Caché ---
if not os.path.exists(CACHE_DIR):
    os.makedirs(CACHE_DIR)
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

fastf1.Cache.enable_cache(CACHE_DIR)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


def process_session_data(session):
    """
    Procesa los datos de una sesión, verificando el tipo de cada conjunto de datos
    antes de manipularlo para evitar errores con datos mal cargados.
    """
    session_data = {'results': None, 'weather': None, 'race_control': None, 'laps': None, 'telemetry': None}

    # --- Extraer Resultados (Results) ---
    try:
        results = session.results
        if isinstance(results, pd.DataFrame) and not results.empty:
            results['Year'] = session.event['EventDate'].year
            results['EventName'] = session.event['EventName']
            results['SessionName'] = session.name
            session_data['results'] = results
        elif not isinstance(results, pd.DataFrame):
            logging.warning(f"  -> Los 'results' para {session.name} no son un DataFrame válido. Datos no disponibles.")
    except Exception as e:
        logging.error(f"  -> Error inesperado al procesar 'results' para {session.name}: {e}")

    # --- Extraer Clima (Weather) ---
    try:
        weather_data = session.weather_data
        if isinstance(weather_data, pd.DataFrame) and not weather_data.empty:
            weather_data['Year'] = session.event['EventDate'].year
            weather_data['EventName'] = session.event['EventName']
            weather_data['SessionName'] = session.name
            session_data['weather'] = weather_data
    except Exception as e:
        logging.error(f"  -> Error inesperado al procesar 'weather_data' para {session.name}: {e}")

    # --- Extraer Mensajes de Control de Carrera (Race Control) ---
    try:
        rcm = session.race_control_messages
        if isinstance(rcm, pd.DataFrame) and not rcm.empty:
            rcm['Year'] = session.event['EventDate'].year
            rcm['EventName'] = session.event['EventName']
            rcm['SessionName'] = session.name
            session_data['race_control'] = rcm
    except Exception as e:
        logging.error(f"  -> Error inesperado al procesar 'race_control_messages' para {session.name}: {e}")
        
    # --- Extraer Vueltas (Laps) y Telemetría ---
    try:
        laps = session.laps
        if isinstance(laps, pd.DataFrame) and not laps.empty:
            laps['Year'] = session.event['EventDate'].year
            laps['EventName'] = session.event['EventName']
            laps['SessionName'] = session.name
            session_data['laps'] = laps

            all_telemetry = []
            logging.info("  -> Extrayendo telemetría vuelta por vuelta...")
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
                    logging.warning(f"    -> No se pudo obtener telemetría para la vuelta {lap['LapNumber']} de {lap['Driver']}: {e}")
            
            if all_telemetry:
                session_data['telemetry'] = pd.concat(all_telemetry, ignore_index=True)
        elif not isinstance(laps, pd.DataFrame):
            logging.warning(f"  -> Los 'laps' para {session.name} no son un DataFrame válido. Telemetría no disponible.")
            
    except Exception as e:
        logging.error(f"  -> Error inesperado al procesar 'laps' y 'telemetry' para {session.name}: {e}")

    return session_data


def main(year):
    """Función principal para orquestar la extracción de datos para un año específico."""
    logging.info(f"--- INICIO DEL PROCESO DE EXTRACCIÓN PARA EL AÑO {year} ---")

    year_output_dir = os.path.join(OUTPUT_DIR, str(year))
    if not os.path.exists(year_output_dir):
        os.makedirs(year_output_dir)
        logging.info(f"Creado directorio de salida: {year_output_dir}")

    all_data_lists = {'events': [], 'sessions': [], 'results': [], 'weather': [], 'race_control': [], 'laps': [], 'telemetry': []}
    rate_limit_delay = INITIAL_RETRY_DELAY

    try:
        schedule = fastf1.get_event_schedule(year, include_testing=False)
        today = pd.to_datetime('today').tz_localize('UTC')
        past_events = schedule[schedule['EventDate'].dt.tz_localize('UTC') < today]
        all_data_lists['events'].append(schedule)

        for _, event in past_events.iterrows():
            logging.info(f"== Evento: {event['EventName']} ==")

            for session_name in SESSION_IDENTIFIERS_TO_FETCH:
                session = None
                retries = 0
                while retries < MAX_RETRIES:
                    try:
                        session = fastf1.get_session(year, event['RoundNumber'], session_name)
                        # CORREGIDO: Se eliminó el argumento 'timeout'
                        session.load(laps=True, telemetry=True, weather=True, messages=True)
                        logging.info(f"Sesión '{session.name}' cargada en memoria.")
                        break

                    except RateLimitExceededError:
                        logging.warning(f"Rate Limit Exceeded. Esperando {rate_limit_delay} seg... (Intento {retries + 1}/{MAX_RETRIES})")
                        time.sleep(rate_limit_delay); retries += 1; rate_limit_delay += RATE_LIMIT_INCREMENT
                    
                    except HTTPError as e:
                        status_code = e.response.status_code if e.response else "N/A"
                        logging.warning(f"Error HTTP {status_code}. Esperando {HTTP_ERROR_DELAY} seg... (Intento {retries + 1}/{MAX_RETRIES})")
                        time.sleep(HTTP_ERROR_DELAY); retries += 1

                    except Exception as e:
                        logging.warning(f"No se pudo cargar la sesión '{session_name}' para {event['EventName']} {year}. Razón: {e}")
                        session = None; break
                
                if retries == MAX_RETRIES:
                    logging.error(f"Se superó el máximo de reintentos para cargar la sesión '{session_name}'.")

                if session:
                    logging.info(f"Procesando datos para la sesión: {session.name}")
                    data = process_session_data(session)

                    all_data_lists['sessions'].append({'Year': year, 'EventName': event['EventName'], 'SessionName': session.name, 'SessionDate': session.date})
                    if data['results'] is not None: all_data_lists['results'].append(data['results'])
                    if data['weather'] is not None: all_data_lists['weather'].append(data['weather'])
                    if data['race_control'] is not None: all_data_lists['race_control'].append(data['race_control'])
                    if data['laps'] is not None: all_data_lists['laps'].append(data['laps'])
                    if data['telemetry'] is not None: all_data_lists['telemetry'].append(data['telemetry'])
                    
                    logging.info(f"Datos de la sesión {session.name} procesados y agregados a la lista.")
                    rate_limit_delay = INITIAL_RETRY_DELAY

    except Exception as e:
        logging.error(f"FALLO CRÍTICO al procesar el año {year}. Razón: {e}")
        
    logging.info(f"--- PROCESO DE GUARDADO EN ARCHIVOS CSV PARA EL AÑO {year} ---")
    
    def save_to_csv(data_list, filename_prefix, output_dir):
        if data_list:
            filename = f"{filename_prefix}_{year}.csv"
            full_path = os.path.join(output_dir, filename)
            logging.info(f"Guardando datos en {full_path}...")
            df = pd.concat(data_list, ignore_index=True)
            df.to_csv(full_path, index=False, encoding='utf-8')
            logging.info(f"Guardado exitoso. Total de filas: {len(df)}")
        else:
            logging.warning(f"No se encontraron datos para guardar en {filename_prefix}_{year}.csv.")
    
    save_to_csv(all_data_lists['events'], 'events', year_output_dir)
    if all_data_lists['sessions']:
        sessions_df = pd.DataFrame(all_data_lists['sessions'])
        sessions_df.to_csv(os.path.join(year_output_dir, f"sessions_{year}.csv"), index=False, encoding='utf-8')

    save_to_csv(all_data_lists['results'], 'results', year_output_dir)
    save_to_csv(all_data_lists['weather'], 'weather', year_output_dir)
    save_to_csv(all_data_lists['race_control'], 'race_control', year_output_dir)
    save_to_csv(all_data_lists['laps'], 'laps', year_output_dir)
    save_to_csv(all_data_lists['telemetry'], 'telemetry', year_output_dir)

    logging.info(f"¡PROCESO DE EXTRACCIÓN PARA EL AÑO {year} COMPLETADO!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extraer datos de la F1 para un año específico y guardarlos en CSV.")
    parser.add_argument("year", type=int, help="El año del campeonato para el cual extraer los datos.")
    args = parser.parse_args()
    main(args.year)