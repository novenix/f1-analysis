# -*- coding: utf-8 -*-
"""
Extractor de Datos de Fórmula 1 por Año (v6)

Este script extrae datos de las sesiones de Carrera ('R') y Sprint ('S')
para un AÑO ESPECÍFICO proporcionado como argumento de línea de comandos.

NUEVAS FUNCIONALIDADES (v6):
- El script se ejecuta para un único año pasado como argumento.
- Crea un subdirectorio para el año especificado dentro de la carpeta de salida.
- Los archivos CSV generados incluyen el año en su nombre para una fácil identificación.
- Mantiene el robusto manejo de errores HTTP y de Rate Limiting.
"""
import fastf1
import pandas as pd
import logging
import os
import time
import argparse  # Importamos argparse para manejar argumentos de línea de comandos
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
    """Procesa y extrae los datos relevantes de una sesión cargada."""
    session_data = {'results': None, 'weather': None, 'race_control': None, 'laps': None, 'telemetry': None}
    
    results = session.results
    if results is not None and not results.empty:
        results['Year'] = session.event['EventDate'].year
        results['EventName'] = session.event['EventName']
        results['SessionName'] = session.name
        session_data['results'] = results

    if session.weather_data is not None and not session.weather_data.empty:
        weather = session.weather_data
        weather['Year'] = session.event['EventDate'].year
        weather['EventName'] = session.event['EventName']
        weather['SessionName'] = session.name
        session_data['weather'] = weather

    if session.race_control_messages is not None and not session.race_control_messages.empty:
        rcm = session.race_control_messages
        rcm['Year'] = session.event['EventDate'].year
        rcm['EventName'] = session.event['EventName']
        rcm['SessionName'] = session.name
        session_data['race_control'] = rcm
        
    if session.laps is not None and not session.laps.empty:
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


# MODIFICADO: La función main ahora recibe el año como parámetro
def main(year):
    """Función principal para orquestar la extracción de datos para un año específico."""
    logging.info(f"--- INICIO DEL PROCESO DE EXTRACCIÓN PARA EL AÑO {year} ---")

    # MODIFICADO: Crear un directorio de salida específico para el año
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
                retries = 0
                while retries < MAX_RETRIES:
                    try:
                        session = fastf1.get_session(year, event['RoundNumber'], session_name)
                        session.load(laps=True, telemetry=True, weather=True, messages=True)
                        
                        logging.info(f"Cargando datos para la sesión: {session.name}")
                        data = process_session_data(session)

                        all_data_lists['sessions'].append({'Year': year, 'EventName': event['EventName'], 'SessionName': session.name, 'SessionDate': session.date})
                        if data['results'] is not None: all_data_lists['results'].append(data['results'])
                        if data['weather'] is not None: all_data_lists['weather'].append(data['weather'])
                        if data['race_control'] is not None: all_data_lists['race_control'].append(data['race_control'])
                        if data['laps'] is not None: all_data_lists['laps'].append(data['laps'])
                        if data['telemetry'] is not None: all_data_lists['telemetry'].append(data['telemetry'])
                        
                        logging.info(f"Datos de la sesión {session.name} cargados con éxito.")
                        rate_limit_delay = INITIAL_RETRY_DELAY
                        break
                    
                    except RateLimitExceededError:
                        logging.warning(f"Rate Limit Exceeded. Esperando {rate_limit_delay} segundos... (Intento {retries + 1}/{MAX_RETRIES})")
                        time.sleep(rate_limit_delay)
                        retries += 1
                        rate_limit_delay += RATE_LIMIT_INCREMENT
                    
                    except HTTPError as e:
                        status_code = e.response.status_code if e.response else "N/A"
                        if status_code == 429:
                            logging.warning(f"API Rate Limit (HTTP 429) detectado. Esperando {HTTP_ERROR_DELAY} segundos... (Intento {retries + 1}/{MAX_RETRIES})")
                        else:
                            logging.warning(f"Error HTTP {status_code}. Esperando {HTTP_ERROR_DELAY} segundos... (Intento {retries + 1}/{MAX_RETRIES})")
                        time.sleep(HTTP_ERROR_DELAY)
                        retries += 1

                    except Exception as e:
                        logging.warning(f"No se pudo cargar la sesión '{session_name}' para {event['EventName']} {year}. Razón: {e}")
                        break
                
                if retries == MAX_RETRIES:
                    logging.error(f"Se superó el máximo de reintentos para la sesión '{session_name}' de {event['EventName']} {year}.")

    except Exception as e:
        logging.error(f"FALLO CRÍTICO al procesar el año {year}. Razón: {e}")
        
    logging.info(f"--- PROCESO DE GUARDADO EN ARCHIVOS CSV PARA EL AÑO {year} ---")
    
    def save_to_csv(data_list, filename_prefix, output_dir):
        if data_list:
            # MODIFICADO: El nombre del archivo ahora incluye el prefijo y el año.
            filename = f"{filename_prefix}_{year}.csv"
            full_path = os.path.join(output_dir, filename)
            logging.info(f"Guardando datos en {full_path}...")
            df = pd.concat(data_list, ignore_index=True)
            df.to_csv(full_path, index=False, encoding='utf-8')
            logging.info(f"Guardado exitoso. Total de filas: {len(df)}")
        else:
            logging.warning(f"No se encontraron datos para guardar en {filename_prefix}_{year}.csv.")
    
    # MODIFICADO: Llamadas a save_to_csv con los nuevos argumentos
    save_to_csv(all_data_lists['events'], 'events', year_output_dir)
    if all_data_lists['sessions']:
        sessions_df = pd.DataFrame(all_data_lists['sessions'])
        sessions_filename = f"sessions_{year}.csv"
        sessions_df.to_csv(os.path.join(year_output_dir, sessions_filename), index=False, encoding='utf-8')

    save_to_csv(all_data_lists['results'], 'results', year_output_dir)
    save_to_csv(all_data_lists['weather'], 'weather', year_output_dir)
    save_to_csv(all_data_lists['race_control'], 'race_control', year_output_dir)
    save_to_csv(all_data_lists['laps'], 'laps', year_output_dir)
    save_to_csv(all_data_lists['telemetry'], 'telemetry', year_output_dir)

    logging.info(f"¡PROCESO DE EXTRACCIÓN PARA EL AÑO {year} COMPLETADO!")


# MODIFICADO: Este es el punto de entrada cuando ejecutas el script
if __name__ == "__main__":
    # 1. Creamos un 'parser' de argumentos
    parser = argparse.ArgumentParser(description="Extraer datos de la F1 para un año específico y guardarlos en CSV.")
    
    # 2. Añadimos el argumento 'year' que será obligatorio y de tipo entero
    parser.add_argument("year", type=int, help="El año del campeonato para el cual extraer los datos.")
    
    # 3. Leemos los argumentos de la línea de comandos
    args = parser.parse_args()
    
    # 4. Llamamos a la función main con el año proporcionado
    #    (ej: si ejecutas 'python script.py 2023', args.year será 2023)
    main(args.year)