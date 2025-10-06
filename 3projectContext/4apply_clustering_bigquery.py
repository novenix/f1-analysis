#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Aplicar Clustering a Tablas Auxiliares - BigQuery F1 Analytics

Este script aplica clustering a las tablas results, weather y race_control
para optimizar queries con JOINs y análisis exploratorio.

IMPORTANTE: Este script ELIMINA y RECREA las tablas con clustering.
           La tabla laps_enriched NO se toca (ya tiene clustering + partición).

Clustering aplicado:
- results: ["Driver", "EventName", "Year"]
- weather: ["EventName", "Year", "SessionName"]
- race_control: ["EventName", "Year", "Category"]
"""

from google.cloud import bigquery
from google.cloud.exceptions import NotFound
import os
import logging

# Configuración
PROJECT_ID = "topicos-bases-datos"
DATASET_ID = "f1_data_warehouse"
DATA_LAKE_DIR = "f1_data_lake_focused"
YEARS = [2021, 2022, 2023, 2024, 2025]

# Configuración de clustering por tabla
# NOTA: En results el campo de piloto se llama "Abbreviation" (ej: HAM, VER)
CLUSTERING_CONFIG = {
    "results": ["Abbreviation", "EventName", "Year"],  # Abbreviation es el código del piloto
    "weather": ["EventName", "Year", "SessionName"],
    "race_control": ["EventName", "Year", "Category"]
}

def setup_logging():
    """Configurar logging para el proceso."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('apply_clustering.log'),
            logging.StreamHandler()
        ]
    )

def get_bigquery_client():
    """Crear cliente de BigQuery."""
    client = bigquery.Client(project=PROJECT_ID)
    logging.info(f"Cliente de BigQuery creado para proyecto: {PROJECT_ID}")
    return client

def delete_table_if_exists(client, table_id):
    """Eliminar tabla si existe."""
    try:
        client.delete_table(table_id)
        logging.info(f"  ✓ Tabla eliminada: {table_id}")
        return True
    except NotFound:
        logging.info(f"  ℹ Tabla no existe: {table_id}")
        return False

def load_csv_with_clustering(client, table_id, csv_path, cluster_fields):
    """
    Cargar CSV a BigQuery con clustering configurado.

    Args:
        client: Cliente de BigQuery
        table_id: ID completo de la tabla
        csv_path: Ruta al archivo CSV
        cluster_fields: Lista de campos para clustering
    """
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        autodetect=True,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        clustering_fields=cluster_fields  # ← Clustering configurado aquí
    )

    with open(csv_path, "rb") as source_file:
        job = client.load_table_from_file(source_file, table_id, job_config=job_config)

    job.result()  # Esperar a que complete

    table = client.get_table(table_id)
    logging.info(f"  ✓ Cargado: {csv_path}")
    logging.info(f"      Filas: {table.num_rows:,}")
    logging.info(f"      Tamaño: {table.num_bytes / (1024**2):.2f} MB")

def append_csv_with_schema(client, table_id, csv_path):
    """
    Añadir CSV usando el schema existente de la tabla.

    Args:
        client: Cliente de BigQuery
        table_id: ID completo de la tabla
        csv_path: Ruta al archivo CSV
    """
    existing_table = client.get_table(table_id)

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        schema=existing_table.schema,  # Usar schema existente
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND
    )

    with open(csv_path, "rb") as source_file:
        job = client.load_table_from_file(source_file, table_id, job_config=job_config)

    job.result()
    logging.info(f"  ✓ Añadido: {csv_path}")

def recreate_table_with_clustering(client, table_name, file_pattern, cluster_fields):
    """
    Eliminar y recrear tabla con clustering aplicado.

    Args:
        client: Cliente de BigQuery
        table_name: Nombre de la tabla (sin dataset)
        file_pattern: Patrón del archivo CSV (ej: 'results_{year}.csv')
        cluster_fields: Lista de campos para clustering
    """
    logging.info("\n" + "="*70)
    logging.info(f"RECREANDO TABLA: {table_name}")
    logging.info("="*70)
    logging.info(f"Clustering: {cluster_fields}")
    logging.info("")

    table_id = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"

    # Paso 1: Eliminar tabla existente
    delete_table_if_exists(client, table_id)

    # Paso 2: Cargar datos con clustering
    for i, year in enumerate(YEARS):
        csv_file = os.path.join(DATA_LAKE_DIR, str(year), file_pattern.format(year=year))

        if not os.path.exists(csv_file):
            logging.warning(f"  ✗ Archivo no encontrado: {csv_file}")
            continue

        logging.info(f"\n  Procesando año {year}...")

        if i == 0:
            # Primera carga: crear tabla con clustering
            load_csv_with_clustering(client, table_id, csv_file, cluster_fields)
        else:
            # Cargas siguientes: APPEND usando schema existente
            append_csv_with_schema(client, table_id, csv_file)

    # Paso 3: Verificar configuración final
    table = client.get_table(table_id)

    logging.info(f"\n  {'='*60}")
    logging.info(f"  TABLA COMPLETADA: {table_name}")
    logging.info(f"  {'='*60}")
    logging.info(f"  Total filas: {table.num_rows:,}")
    logging.info(f"  Tamaño: {table.num_bytes / (1024**2):.2f} MB")

    if table.clustering_fields:
        logging.info(f"  ✅ Clustering: {table.clustering_fields}")
    else:
        logging.warning(f"  ⚠️ Clustering NO aplicado")

def verify_clustering(client):
    """Verificar que todas las tablas tengan clustering aplicado."""
    logging.info("\n" + "="*70)
    logging.info("VERIFICACIÓN FINAL DE CLUSTERING")
    logging.info("="*70)

    for table_name, expected_clustering in CLUSTERING_CONFIG.items():
        table_id = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"
        table = client.get_table(table_id)

        logging.info(f"\n{table_name}:")
        logging.info(f"  Filas: {table.num_rows:,}")
        logging.info(f"  Clustering configurado: {table.clustering_fields}")

        if table.clustering_fields == expected_clustering:
            logging.info(f"  ✅ Clustering CORRECTO")
        else:
            logging.error(f"  ❌ Clustering INCORRECTO - Esperado: {expected_clustering}")

def main():
    """Función principal."""
    setup_logging()

    logging.info("="*70)
    logging.info("APLICAR CLUSTERING A TABLAS AUXILIARES")
    logging.info("="*70)
    logging.info(f"Proyecto: {PROJECT_ID}")
    logging.info(f"Dataset: {DATASET_ID}")
    logging.info("")
    logging.info("Tablas a modificar:")
    for table_name, cluster_fields in CLUSTERING_CONFIG.items():
        logging.info(f"  • {table_name}: {cluster_fields}")
    logging.info("")
    logging.info("⚠️  ADVERTENCIA: Las tablas serán eliminadas y recreadas")
    logging.info("⚠️  La tabla laps_enriched NO será modificada")
    logging.info("")

    # Crear cliente
    client = get_bigquery_client()

    # Recrear cada tabla con clustering
    recreate_table_with_clustering(
        client,
        "results",
        "results_{year}.csv",
        CLUSTERING_CONFIG["results"]
    )

    recreate_table_with_clustering(
        client,
        "weather",
        "weather_{year}.csv",
        CLUSTERING_CONFIG["weather"]
    )

    recreate_table_with_clustering(
        client,
        "race_control",
        "race_control_{year}.csv",
        CLUSTERING_CONFIG["race_control"]
    )

    # Verificación final
    verify_clustering(client)

    logging.info("\n" + "="*70)
    logging.info("✅ CLUSTERING APLICADO EXITOSAMENTE")
    logging.info("="*70)
    logging.info("\nPróximos pasos:")
    logging.info("  1. Ejecutar queries de prueba para verificar performance")
    logging.info("  2. Las queries con JOINs deberían procesar menos bytes")
    logging.info("  3. Usar EventName, Driver, Year en WHERE para máxima eficiencia")

if __name__ == "__main__":
    main()
