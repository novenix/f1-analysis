# -*- coding: utf-8 -*-
"""
Finalización de ETL para Laps - Desnormalización con Events (v1.0)

Este script completa el proceso de ETL añadiendo columnas de contexto
de events a los archivos laps_enriched.csv para optimizar BigQuery.

FUNCIONALIDADES:
- Procesa todos los años (2021-2025) automáticamente
- Lee laps_año_enriched.csv y events_año.csv
- Añade columnas: Country, Location, OfficialEventName, EventDate, EventFormat
- Genera: laps_año_enriched_final.csv
- Logging detallado del proceso

ARQUITECTURA:
Este ETL pre-carga permite crear una tabla "ancha" desnormalizada para BigQuery,
evitando JOINs costosos en tiempo de consulta y optimizando el rendimiento analítico.
"""

import pandas as pd
import logging
import os
from pathlib import Path

# --- Configuración ---
DATA_LAKE_DIR = 'f1_data_lake_focused'
YEARS = [2021, 2022, 2023, 2024, 2025]

def setup_logging():
    """Configurar logging para el proceso completo."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('finish_etl_laps.log'),
            logging.StreamHandler()
        ]
    )

def load_events_data(year):
    """Cargar datos de events para un año específico."""
    events_file = os.path.join(DATA_LAKE_DIR, str(year), f'events_{year}.csv')

    if not os.path.exists(events_file):
        raise FileNotFoundError(f"No se encontró el archivo de events: {events_file}")

    events_df = pd.read_csv(events_file)

    # Seleccionar solo las columnas que necesitamos para la desnormalización
    required_columns = ['EventName', 'Country', 'Location', 'OfficialEventName', 'EventDate', 'EventFormat']

    # Verificar que todas las columnas existan
    missing_cols = [col for col in required_columns if col not in events_df.columns]
    if missing_cols:
        raise ValueError(f"Faltan columnas en events_{year}.csv: {missing_cols}")

    events_df = events_df[required_columns]

    logging.info(f"Cargado events_{year}.csv: {len(events_df)} eventos")

    return events_df

def load_laps_enriched(year):
    """Cargar datos de laps enriched para un año específico."""
    laps_file = os.path.join(DATA_LAKE_DIR, str(year), f'laps_{year}_enriched.csv')

    if not os.path.exists(laps_file):
        raise FileNotFoundError(f"No se encontró el archivo: {laps_file}")

    laps_df = pd.read_csv(laps_file)

    logging.info(f"Cargado laps_{year}_enriched.csv: {len(laps_df)} vueltas, {len(laps_df.columns)} columnas")

    return laps_df

def denormalize_laps(laps_df, events_df, year):
    """
    Desnormalizar laps_enriched añadiendo columnas de events.

    Realiza un LEFT JOIN de laps con events usando EventName como clave.
    """
    logging.info(f"Iniciando desnormalización para año {year}...")

    # Verificar que EventName existe en ambos DataFrames
    if 'EventName' not in laps_df.columns:
        raise ValueError(f"'EventName' no existe en laps_{year}_enriched.csv")

    # Realizar merge (LEFT JOIN)
    laps_final_df = laps_df.merge(
        events_df,
        on='EventName',
        how='left',
        validate='m:1'  # Muchas vueltas a un evento
    )

    # Verificar que se añadieron las columnas
    new_columns = ['Country', 'Location', 'OfficialEventName', 'EventDate', 'EventFormat']
    added_columns = [col for col in new_columns if col in laps_final_df.columns]

    logging.info(f"Columnas añadidas: {added_columns}")

    # Verificar si hay vueltas sin match
    null_counts = laps_final_df[new_columns].isnull().sum()
    if null_counts.any():
        logging.warning(f"Advertencia - Valores NULL encontrados después del merge:\n{null_counts[null_counts > 0]}")

    logging.info(f"Desnormalización completada: {len(laps_final_df)} vueltas, {len(laps_final_df.columns)} columnas")

    return laps_final_df

def save_final_data(laps_final_df, year):
    """Guardar datos finales desnormalizados."""
    output_dir = os.path.join(DATA_LAKE_DIR, str(year))

    # Asegurar que el directorio existe
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    output_file = os.path.join(output_dir, f'laps_{year}_enriched_final.csv')

    laps_final_df.to_csv(output_file, index=False, encoding='utf-8')

    # Obtener tamaño del archivo
    file_size_mb = os.path.getsize(output_file) / (1024 * 1024)

    logging.info(f"✓ Archivo guardado: {output_file}")
    logging.info(f"  - Tamaño: {file_size_mb:.2f} MB")
    logging.info(f"  - Filas: {len(laps_final_df):,}")
    logging.info(f"  - Columnas: {len(laps_final_df.columns)}")

def process_year(year):
    """Procesar un año completo: cargar, desnormalizar y guardar."""
    logging.info(f"\n{'='*60}")
    logging.info(f"PROCESANDO AÑO {year}")
    logging.info(f"{'='*60}")

    try:
        # 1. Cargar events
        events_df = load_events_data(year)

        # 2. Cargar laps enriched
        laps_df = load_laps_enriched(year)

        # 3. Desnormalizar
        laps_final_df = denormalize_laps(laps_df, events_df, year)

        # 4. Guardar resultado final
        save_final_data(laps_final_df, year)

        logging.info(f"✓ Año {year} completado exitosamente\n")

        return True

    except Exception as e:
        logging.error(f"✗ Error procesando año {year}: {e}")
        return False

def main():
    """Función principal: procesar todos los años."""
    setup_logging()

    logging.info("="*60)
    logging.info("INICIO - FINALIZACIÓN DE ETL PARA LAPS (2021-2025)")
    logging.info("="*60)
    logging.info("Objetivo: Desnormalizar laps_enriched con datos de events")
    logging.info("Columnas a añadir: Country, Location, OfficialEventName, EventDate, EventFormat")
    logging.info("")

    results = {}

    for year in YEARS:
        success = process_year(year)
        results[year] = success

    # Resumen final
    logging.info("\n" + "="*60)
    logging.info("RESUMEN FINAL")
    logging.info("="*60)

    for year, success in results.items():
        status = "✓ EXITOSO" if success else "✗ FALLIDO"
        logging.info(f"  {year}: {status}")

    total_success = sum(results.values())
    logging.info(f"\nTotal: {total_success}/{len(YEARS)} años procesados exitosamente")

    if total_success == len(YEARS):
        logging.info("\n¡PROCESO COMPLETADO AL 100%!")
        logging.info("Los archivos están listos para ser cargados a BigQuery.")
    else:
        logging.warning("\nAlgunos años fallaron. Revisar logs para detalles.")

if __name__ == "__main__":
    main()
