#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fix Timestamp Columns - Remove '0 days' from CSV files

Este script:
1. Detecta automáticamente columnas que contienen valores con formato '0 days HH:MM:SS'
2. Convierte esos valores a formato TIME estándar 'HH:MM:SS'
3. Guarda los archivos modificados con sufijo '_timestamp.csv'
4. Genera un reporte de los archivos procesados

IMPORTANTE: Solo procesa archivos que realmente tienen el problema de '0 days'
"""

import pandas as pd
import os
import re
from pathlib import Path
import logging

# Configuración
DATA_LAKE_DIR = "f1_data_lake_focused"
YEARS = [2021, 2022, 2023, 2024, 2025]
TIMESTAMP_PATTERN = re.compile(r'0 days (\d{2}:\d{2}:\d{2}(?:\.\d+)?)')

def setup_logging():
    """Configurar logging."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('fix_timestamp_columns.log'),
            logging.StreamHandler()
        ]
    )

def has_zero_days_format(value):
    """
    Verificar si un valor tiene formato '0 days HH:MM:SS'.

    Args:
        value: Valor a verificar (puede ser cualquier tipo)

    Returns:
        bool: True si tiene formato '0 days'
    """
    if pd.isna(value):
        return False

    value_str = str(value).strip()
    return value_str.startswith('0 days ')

def convert_timestamp_value(value):
    """
    Convertir valor de '0 days HH:MM:SS' a 'HH:MM:SS'.

    Args:
        value: Valor a convertir

    Returns:
        str: Valor convertido o valor original si no aplica
    """
    if pd.isna(value):
        return value

    value_str = str(value).strip()

    # Buscar patrón '0 days HH:MM:SS'
    match = TIMESTAMP_PATTERN.match(value_str)
    if match:
        # Extraer solo la parte de tiempo
        time_part = match.group(1)
        return time_part

    return value

def detect_timestamp_columns(df):
    """
    Detectar columnas que tienen valores con formato '0 days'.

    Args:
        df: DataFrame a analizar

    Returns:
        list: Lista de nombres de columnas con formato '0 days'
    """
    timestamp_columns = []

    for col in df.columns:
        # Tomar muestra de valores no nulos
        sample = df[col].dropna().head(100)

        if len(sample) == 0:
            continue

        # Verificar si al menos un valor tiene formato '0 days'
        has_zero_days = any(has_zero_days_format(val) for val in sample)

        if has_zero_days:
            timestamp_columns.append(col)

    return timestamp_columns

def fix_timestamp_columns_in_file(csv_path):
    """
    Detectar y corregir columnas con '0 days' en un archivo CSV.

    Args:
        csv_path: Ruta al archivo CSV

    Returns:
        dict: Información sobre el procesamiento
    """
    result = {
        'file': csv_path,
        'processed': False,
        'timestamp_columns': [],
        'rows': 0,
        'output_file': None,
        'error': None
    }

    try:
        # Leer CSV
        logging.info(f"  Leyendo: {csv_path}")
        df = pd.read_csv(csv_path, low_memory=False)
        result['rows'] = len(df)

        # Detectar columnas con '0 days'
        timestamp_columns = detect_timestamp_columns(df)
        result['timestamp_columns'] = timestamp_columns

        if not timestamp_columns:
            logging.info(f"  ✓ No se encontraron columnas con '0 days' - archivo sin cambios")
            return result

        logging.info(f"  📋 Columnas con '0 days' detectadas: {len(timestamp_columns)}")
        for col in timestamp_columns:
            logging.info(f"      - {col}")

        # Convertir valores en columnas detectadas
        for col in timestamp_columns:
            df[col] = df[col].apply(convert_timestamp_value)

        # Generar nombre de archivo de salida
        path_obj = Path(csv_path)

        # Si ya tiene _timestamp, reemplazar el archivo
        if '_timestamp.csv' in path_obj.name:
            output_path = csv_path
        else:
            # Añadir _timestamp antes de .csv
            output_path = str(path_obj.parent / f"{path_obj.stem}_timestamp.csv")

        # Guardar archivo modificado
        df.to_csv(output_path, index=False)
        result['output_file'] = output_path
        result['processed'] = True

        logging.info(f"  ✅ Archivo procesado y guardado: {output_path}")

    except Exception as e:
        result['error'] = str(e)
        logging.error(f"  ❌ Error procesando archivo: {e}")

    return result

def process_all_files():
    """
    Procesar todos los archivos CSV en el data lake.

    Returns:
        dict: Estadísticas del procesamiento
    """
    logging.info("=" * 70)
    logging.info("INICIO - CORRECCIÓN DE COLUMNAS TIMESTAMP")
    logging.info("=" * 70)
    logging.info(f"Directorio: {DATA_LAKE_DIR}")
    logging.info(f"Años: {YEARS}")
    logging.info("")

    stats = {
        'total_files': 0,
        'files_processed': 0,
        'files_skipped': 0,
        'files_error': 0,
        'results': []
    }

    # Procesar cada año
    for year in YEARS:
        year_dir = os.path.join(DATA_LAKE_DIR, str(year))

        if not os.path.exists(year_dir):
            logging.warning(f"⚠️  Directorio no encontrado: {year_dir}")
            continue

        logging.info(f"\n{'=' * 70}")
        logging.info(f"PROCESANDO AÑO: {year}")
        logging.info(f"{'=' * 70}\n")

        # Obtener todos los archivos CSV (excepto los que ya son _timestamp)
        csv_files = [
            f for f in os.listdir(year_dir)
            if f.endswith('.csv') and not f.endswith('_timestamp.csv')
        ]

        for csv_file in sorted(csv_files):
            csv_path = os.path.join(year_dir, csv_file)
            stats['total_files'] += 1

            logging.info(f"\n{csv_file}")

            result = fix_timestamp_columns_in_file(csv_path)
            stats['results'].append(result)

            if result['processed']:
                stats['files_processed'] += 1
            elif result['error']:
                stats['files_error'] += 1
            else:
                stats['files_skipped'] += 1

    return stats

def generate_report(stats):
    """
    Generar reporte final del procesamiento.

    Args:
        stats: Estadísticas del procesamiento
    """
    logging.info("\n" + "=" * 70)
    logging.info("REPORTE FINAL")
    logging.info("=" * 70)
    logging.info(f"Total archivos analizados: {stats['total_files']}")
    logging.info(f"Archivos procesados (con cambios): {stats['files_processed']}")
    logging.info(f"Archivos sin cambios: {stats['files_skipped']}")
    logging.info(f"Archivos con errores: {stats['files_error']}")
    logging.info("")

    # Archivos procesados
    if stats['files_processed'] > 0:
        logging.info("ARCHIVOS CON CAMBIOS:")
        logging.info("-" * 70)
        for result in stats['results']:
            if result['processed']:
                logging.info(f"\n✓ {result['file']}")
                logging.info(f"    Filas: {result['rows']:,}")
                logging.info(f"    Columnas modificadas: {len(result['timestamp_columns'])}")
                logging.info(f"    Guardado en: {result['output_file']}")

    # Errores
    if stats['files_error'] > 0:
        logging.info("\n\nARCHIVOS CON ERRORES:")
        logging.info("-" * 70)
        for result in stats['results']:
            if result['error']:
                logging.info(f"\n✗ {result['file']}")
                logging.info(f"    Error: {result['error']}")

    logging.info("\n" + "=" * 70)
    logging.info("✅ PROCESO COMPLETADO")
    logging.info("=" * 70)
    logging.info("\nPróximos pasos:")
    logging.info("  1. Verificar archivos *_timestamp.csv generados")
    logging.info("  2. Ejecutar script de carga a BigQuery")
    logging.info("  3. Verificar tipos de datos en BigQuery Console")

def main():
    """Función principal."""
    setup_logging()

    # Verificar que existe el directorio
    if not os.path.exists(DATA_LAKE_DIR):
        logging.error(f"❌ Directorio no encontrado: {DATA_LAKE_DIR}")
        return

    # Procesar archivos
    stats = process_all_files()

    # Generar reporte
    generate_report(stats)

if __name__ == "__main__":
    main()
