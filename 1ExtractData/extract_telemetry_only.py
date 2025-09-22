import fastf1
import pandas as pd
import os
from datetime import timezone

# Define un directorio para el caché para acelerar las descargas futuras
CACHE_DIR = 'cache'
if not os.path.exists(CACHE_DIR):
    os.makedirs(CACHE_DIR)
fastf1.Cache.enable_cache(CACHE_DIR)

def obtener_telemetria_carrera_f1(year, base_path='f1_telemetry_data'):
    """
    Descarga y guarda los datos de telemetría de la sesión de Carrera (Race)
    de F1 para un año específico, enfocándose únicamente en la telemetría.

    Args:
        year (int): El año de la temporada de F1.
        base_path (str): El directorio base donde se guardarán los datos.
    """
    print(f"--- Iniciando la extracción de datos de Telemetría de Carrera para el año {year} ---")

    # Crear el directorio base para el año si no existe
    year_path = os.path.join(base_path, str(year))
    if not os.path.exists(year_path):
        os.makedirs(year_path)

    try:
        schedule = fastf1.get_event_schedule(year, include_testing=False)
    except Exception as e:
        print(f"No se pudo obtener el calendario para el año {year}. Error: {e}")
        return

    now_utc = pd.Timestamp.now(tz=timezone.utc)

    # Iterar sobre cada evento del calendario
    for _, event in schedule.iterrows():
        event_date_utc = event['EventDate'].tz_localize('UTC')

        if now_utc < event_date_utc:
            print(f"\nOmitiendo evento futuro: {event['EventName']}")
            continue

        print(f"\nProcesando evento: {event['EventName']} (Ronda {event['RoundNumber']})")

        try:
            session = fastf1.get_session(year, event['RoundNumber'], 'R')
            session.load(laps=True, telemetry=True, weather=False, messages=False)

            event_name_safe = event['EventName'].replace(' ', '_').replace('/', '_')
            event_path = os.path.join(year_path, event_name_safe)
            if not os.path.exists(event_path):
                os.makedirs(event_path)

            laps = session.laps
            drivers = session.drivers

            for driver_num in drivers:
                # CORRECCIÓN 1: Usar pick_drivers() en lugar del obsoleto pick_driver()
                driver_laps = laps.pick_drivers(driver_num)
                if driver_laps.empty:
                    continue

                driver_tla = driver_laps.iloc[0]['Driver']
                print(f"    -> Extrayendo telemetría para el piloto: {driver_tla}")

                # Lista para almacenar la telemetría de cada vuelta
                telemetry_for_all_laps = []

                # CORRECCIÓN 2: Iterar correctamente desempaquetando la tupla (index, lap)
                for index, lap in driver_laps.iterlaps():
                    try:
                        # 'lap' es ahora el objeto correcto con los datos de la vuelta
                        telemetry = lap.get_telemetry()
                        # Añadimos la columna 'LapNumber' para poder hacer JOINs después
                        telemetry['LapNumber'] = lap['LapNumber']
                        telemetry_for_all_laps.append(telemetry)
                    except Exception as e:
                        print(f"      [AVISO] No se pudo obtener telemetría para {driver_tla} en la vuelta {lap['LapNumber']}: {e}")

                if telemetry_for_all_laps:
                    # Combinamos la telemetría de todas las vueltas en un único DataFrame
                    full_driver_telemetry = pd.concat(telemetry_for_all_laps)
                    
                    # Guardamos un solo archivo por piloto, que es más eficiente
                    file_name = f"telemetry_{driver_tla}.csv"
                    file_path = os.path.join(event_path, file_name)
                    full_driver_telemetry.to_csv(file_path, index=False)
                    print(f"      [OK] Archivo guardado: {file_name}")
                else:
                    print(f"      [AVISO] No se encontró telemetría para {driver_tla} en este evento.")

        except Exception as e:
            print(f"  [ERROR] No se pudo cargar la sesión de Carrera para '{event['EventName']}': {e}")

    print(f"\n--- Extracción de datos para el año {year} completada ---")


# --- Ejemplo de uso para el año 2024 ---
obtener_telemetria_carrera_f1(2025)