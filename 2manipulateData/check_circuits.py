# -*- coding: utf-8 -*-
"""
Verificador de Circuitos Disponibles (v1.0)

Este script verifica qué circuitos están disponibles en los archivos de laps
vs los directorios de telemetría para un año específico.

FUNCIONALIDADES:
- Lista circuitos en archivo laps_año.csv
- Lista directorios de circuitos en f1_telemetry_data/año/
- Compara y muestra diferencias
- Mapea nombres con espacios vs underscores
"""

import pandas as pd
import os
import logging
import argparse

# --- Configuración de Directorios ---
DATA_LAKE_DIR = 'f1_data_lake_focused'
TELEMETRY_DIR = 'f1_telemetry_data'

def setup_logging():
    """Configurar logging básico."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

def get_circuits_from_laps(year):
    """Obtener lista de circuitos del archivo de laps."""
    laps_file = os.path.join(DATA_LAKE_DIR, str(year), f'laps_{year}.csv')

    if not os.path.exists(laps_file):
        logging.error(f"No se encontró el archivo de laps: {laps_file}")
        return []

    try:
        laps_df = pd.read_csv(laps_file)
        circuits_in_laps = sorted(laps_df['EventName'].unique())

        logging.info(f"=== CIRCUITOS EN LAPS_{year}.CSV ===")
        for i, circuit in enumerate(circuits_in_laps, 1):
            logging.info(f"{i:2d}. {circuit}")

        return circuits_in_laps

    except Exception as e:
        logging.error(f"Error leyendo archivo de laps: {e}")
        return []

def get_circuits_from_telemetry(year):
    """Obtener lista de directorios de circuitos en telemetría."""
    telemetry_year_dir = os.path.join(TELEMETRY_DIR, str(year))

    if not os.path.exists(telemetry_year_dir):
        logging.error(f"No se encontró el directorio de telemetría: {telemetry_year_dir}")
        return []

    try:
        # Obtener solo directorios (no archivos)
        all_items = os.listdir(telemetry_year_dir)
        circuit_dirs = []

        for item in all_items:
            item_path = os.path.join(telemetry_year_dir, item)
            if os.path.isdir(item_path):
                circuit_dirs.append(item)

        circuits_in_telemetry = sorted(circuit_dirs)

        logging.info(f"\n=== CIRCUITOS EN F1_TELEMETRY_DATA/{year}/ ===")
        for i, circuit in enumerate(circuits_in_telemetry, 1):
            logging.info(f"{i:2d}. {circuit}")

        return circuits_in_telemetry

    except Exception as e:
        logging.error(f"Error leyendo directorios de telemetría: {e}")
        return []

def convert_name_to_telemetry_format(circuit_name):
    """Convertir nombre de circuito de laps a formato de telemetría."""
    return circuit_name.replace(' ', '_')

def convert_name_to_laps_format(circuit_dir):
    """Convertir nombre de directorio de telemetría a formato de laps."""
    return circuit_dir.replace('_', ' ')

def compare_circuits(circuits_laps, circuits_telemetry):
    """Comparar circuitos entre laps y telemetría."""
    logging.info(f"\n=== COMPARACIÓN DE CIRCUITOS ===")

    # Convertir nombres de laps a formato telemetría para comparación
    laps_converted = {circuit: convert_name_to_telemetry_format(circuit)
                      for circuit in circuits_laps}

    # Encontrar coincidencias
    matching_circuits = []
    for lap_circuit, telemetry_format in laps_converted.items():
        if telemetry_format in circuits_telemetry:
            matching_circuits.append((lap_circuit, telemetry_format))

    # Encontrar circuitos solo en laps
    only_in_laps = []
    for lap_circuit, telemetry_format in laps_converted.items():
        if telemetry_format not in circuits_telemetry:
            only_in_laps.append(lap_circuit)

    # Encontrar circuitos solo en telemetría
    telemetry_converted = [convert_name_to_laps_format(circuit)
                          for circuit in circuits_telemetry]
    only_in_telemetry = []
    for tel_circuit in circuits_telemetry:
        lap_format = convert_name_to_laps_format(tel_circuit)
        if lap_format not in circuits_laps:
            only_in_telemetry.append(tel_circuit)

    # Mostrar resultados
    logging.info(f"Total circuitos en laps: {len(circuits_laps)}")
    logging.info(f"Total circuitos en telemetría: {len(circuits_telemetry)}")
    logging.info(f"Circuitos que coinciden: {len(matching_circuits)}")

    if matching_circuits:
        logging.info(f"\n--- CIRCUITOS CON DATOS COMPLETOS ---")
        for i, (lap_name, tel_name) in enumerate(matching_circuits, 1):
            logging.info(f"{i:2d}. {lap_name} ↔ {tel_name}")

    if only_in_laps:
        logging.info(f"\n--- CIRCUITOS SOLO EN LAPS (SIN TELEMETRÍA) ---")
        for i, circuit in enumerate(only_in_laps, 1):
            expected_tel_name = convert_name_to_telemetry_format(circuit)
            logging.info(f"{i:2d}. {circuit} (esperado: {expected_tel_name})")

    if only_in_telemetry:
        logging.info(f"\n--- CIRCUITOS SOLO EN TELEMETRÍA (SIN LAPS) ---")
        for i, circuit in enumerate(only_in_telemetry, 1):
            expected_lap_name = convert_name_to_laps_format(circuit)
            logging.info(f"{i:2d}. {circuit} (esperado: {expected_lap_name})")

    return matching_circuits, only_in_laps, only_in_telemetry

def main(year):
    """Función principal para verificar circuitos disponibles."""
    setup_logging()

    logging.info(f"=== VERIFICACIÓN DE CIRCUITOS PARA EL AÑO {year} ===")

    # Obtener circuitos de ambas fuentes
    circuits_laps = get_circuits_from_laps(year)
    circuits_telemetry = get_circuits_from_telemetry(year)

    if not circuits_laps and not circuits_telemetry:
        logging.error("No se encontraron datos para verificar")
        return

    # Comparar circuitos
    matching, only_laps, only_telemetry = compare_circuits(circuits_laps, circuits_telemetry)

    # Resumen final
    logging.info(f"\n=== RESUMEN ===")
    if matching:
        logging.info(f"✓ {len(matching)} circuitos tienen datos completos (laps + telemetría)")
    if only_laps:
        logging.info(f"⚠ {len(only_laps)} circuitos tienen solo datos de laps")
    if only_telemetry:
        logging.info(f"⚠ {len(only_telemetry)} circuitos tienen solo datos de telemetría")

    if not only_laps and not only_telemetry:
        logging.info("🎉 Todos los circuitos tienen datos completos!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Verificar circuitos disponibles en laps vs telemetría")
    parser.add_argument("year", type=int, help="Año para verificar (ej: 2021, 2022, 2025)")
    args = parser.parse_args()

    main(args.year)