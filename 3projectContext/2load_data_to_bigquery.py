# -*- coding: utf-8 -*-
"""
Carga de Datos a BigQuery - Proyecto F1 Analytics

Este script carga automáticamente todos los datos preparados a BigQuery,
creando tablas optimizadas con particionamiento y clustering.

TABLAS A CREAR (según arquitectura del proyecto):
1. laps_enriched - Tabla principal con telemetría (particionada por EventDate, clustered por Driver, EventName)
   - Ya incluye datos de events y sessions (desnormalizada)
2. weather - Datos meteorológicos
3. race_control - Mensajes de control de carrera
4. results - Resultados de sesiones (tabla de conveniencia para BI)
"""

from google.cloud import bigquery
from google.cloud.exceptions import NotFound
import os
import logging
from pathlib import Path

# Configuración
PROJECT_ID = "topicos-bases-datos"
DATASET_ID = "f1_data_warehouse"
DATA_LAKE_DIR = "f1_data_lake_focused"
YEARS = [2021, 2022, 2023, 2024, 2025]

def setup_logging():
    """Configurar logging para el proceso."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('bigquery_load.log'),
            logging.StreamHandler()
        ]
    )

def get_bigquery_client():
    """Crear cliente de BigQuery."""
    client = bigquery.Client(project=PROJECT_ID)
    logging.info(f"Cliente de BigQuery creado para proyecto: {PROJECT_ID}")
    return client

def create_or_get_table(client, table_id, schema=None, partition_field=None, cluster_fields=None):
    """
    Crear tabla si no existe, con opciones de particionamiento y clustering.

    Args:
        client: Cliente de BigQuery
        table_id: ID completo de la tabla (project.dataset.table)
        schema: Schema de la tabla (opcional, auto-detectar si None)
        partition_field: Campo para particionar (opcional)
        cluster_fields: Lista de campos para clustering (opcional)
    """
    try:
        table = client.get_table(table_id)
        logging.info(f"Tabla {table_id} ya existe, será sobrescrita.")
        client.delete_table(table_id)
        logging.info(f"Tabla {table_id} eliminada para recarga.")
    except NotFound:
        logging.info(f"Tabla {table_id} no existe, se creará nueva.")

    # Configurar tabla
    table = bigquery.Table(table_id, schema=schema)

    # Particionamiento
    if partition_field:
        table.time_partitioning = bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field=partition_field
        )
        logging.info(f"  ↳ Particionamiento configurado por campo: {partition_field}")

    # Clustering
    if cluster_fields:
        table.clustering_fields = cluster_fields
        logging.info(f"  ↳ Clustering configurado por campos: {cluster_fields}")

    return table

def load_csv_to_bigquery(client, table_id, csv_path, partition_field=None, cluster_fields=None):
    """
    Cargar archivo CSV a BigQuery con configuración optimizada.

    Args:
        client: Cliente de BigQuery
        table_id: ID completo de la tabla
        csv_path: Ruta al archivo CSV
        partition_field: Campo de particionamiento (opcional)
        cluster_fields: Campos de clustering (opcional)
    """
    # Configurar trabajo de carga
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,  # Saltar header
        autodetect=True,      # Auto-detectar schema
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE  # Sobrescribir
    )

    # Añadir configuración de particionamiento si se especifica
    if partition_field:
        job_config.time_partitioning = bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field=partition_field
        )

    # Añadir clustering si se especifica
    if cluster_fields:
        job_config.clustering_fields = cluster_fields

    # Cargar archivo
    with open(csv_path, "rb") as source_file:
        job = client.load_table_from_file(source_file, table_id, job_config=job_config)

    # Esperar a que complete
    job.result()

    # Obtener info de la tabla cargada
    table = client.get_table(table_id)
    logging.info(f"✓ Cargado: {csv_path}")
    logging.info(f"  ↳ Filas: {table.num_rows:,}")
    logging.info(f"  ↳ Tamaño: {table.num_bytes / (1024**2):.2f} MB")

def load_laps_enriched(client):
    """Cargar tabla principal laps_enriched de todos los años."""
    logging.info("\n" + "="*60)
    logging.info("CARGANDO TABLA: laps_enriched")
    logging.info("="*60)

    table_id = f"{PROJECT_ID}.{DATASET_ID}.laps_enriched"

    # Cargar datos de todos los años
    for year in YEARS:
        csv_file = os.path.join(DATA_LAKE_DIR, str(year), f"laps_{year}_enriched_final.csv")

        if not os.path.exists(csv_file):
            logging.warning(f"✗ Archivo no encontrado: {csv_file}")
            continue

        logging.info(f"\nCargando año {year}...")

        # Primera carga: crear tabla con configuración
        if year == YEARS[0]:
            load_csv_to_bigquery(
                client,
                table_id,
                csv_file,
                partition_field="EventDate",
                cluster_fields=["Driver", "EventName", "Country"]
            )
        else:
            # Cargas siguientes: APPEND en vez de TRUNCATE
            job_config = bigquery.LoadJobConfig(
                source_format=bigquery.SourceFormat.CSV,
                skip_leading_rows=1,
                autodetect=True,
                write_disposition=bigquery.WriteDisposition.WRITE_APPEND
            )

            with open(csv_file, "rb") as source_file:
                job = client.load_table_from_file(source_file, table_id, job_config=job_config)

            job.result()
            logging.info(f"✓ Añadido año {year} a laps_enriched")

    # Info final de la tabla
    table = client.get_table(table_id)
    logging.info(f"\n{'='*40}")
    logging.info(f"TABLA COMPLETA: laps_enriched")
    logging.info(f"{'='*40}")
    logging.info(f"Total de filas: {table.num_rows:,}")
    logging.info(f"Tamaño total: {table.num_bytes / (1024**2):.2f} MB")
    logging.info(f"Particionada por: EventDate")
    logging.info(f"Clustering: Driver, EventName, Country")

def load_simple_table(client, table_name, file_pattern):
    """
    Cargar tabla simple (weather, race_control, results, etc.) de todos los años.

    Args:
        client: Cliente de BigQuery
        table_name: Nombre de la tabla (sin año)
        file_pattern: Patrón del archivo (ej: 'weather_{year}.csv')
    """
    logging.info("\n" + "="*60)
    logging.info(f"CARGANDO TABLA: {table_name}")
    logging.info("="*60)

    table_id = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"

    for year in YEARS:
        csv_file = os.path.join(DATA_LAKE_DIR, str(year), file_pattern.format(year=year))

        if not os.path.exists(csv_file):
            logging.warning(f"✗ Archivo no encontrado: {csv_file}")
            continue

        logging.info(f"\nCargando {table_name} año {year}...")

        if year == YEARS[0]:
            load_csv_to_bigquery(client, table_id, csv_file)
        else:
            # APPEND para años siguientes - usar schema existente
            existing_table = client.get_table(table_id)

            job_config = bigquery.LoadJobConfig(
                source_format=bigquery.SourceFormat.CSV,
                skip_leading_rows=1,
                schema=existing_table.schema,  # Usar schema existente en vez de autodetect
                write_disposition=bigquery.WriteDisposition.WRITE_APPEND
            )

            with open(csv_file, "rb") as source_file:
                job = client.load_table_from_file(source_file, table_id, job_config=job_config)

            job.result()
            logging.info(f"✓ Añadido año {year} a {table_name}")

    # Info final
    table = client.get_table(table_id)
    logging.info(f"\nTabla {table_name} completa:")
    logging.info(f"  Total filas: {table.num_rows:,}")
    logging.info(f"  Tamaño: {table.num_bytes / (1024**2):.2f} MB")

def main():
    """Función principal para cargar todos los datos."""
    setup_logging()

    logging.info("="*60)
    logging.info("INICIO - CARGA DE DATOS A BIGQUERY")
    logging.info("="*60)
    logging.info(f"Proyecto: {PROJECT_ID}")
    logging.info(f"Dataset: {DATASET_ID}")
    logging.info(f"Años: {YEARS}")
    logging.info("")

    # Crear cliente
    client = get_bigquery_client()

    # 1. Cargar tabla principal (laps_enriched)
    load_laps_enriched(client)

    # 2. Cargar tablas auxiliares
    load_simple_table(client, "weather", "weather_{year}.csv")
    load_simple_table(client, "race_control", "race_control_{year}.csv")
    load_simple_table(client, "results", "results_{year}.csv")

    # NOTA: events y sessions NO se cargan a BigQuery porque ya están
    # desnormalizados dentro de laps_enriched_final.csv

    # Resumen final
    logging.info("\n" + "="*60)
    logging.info("RESUMEN FINAL")
    logging.info("="*60)

    tables = client.list_tables(f"{PROJECT_ID}.{DATASET_ID}")
    logging.info("\nTablas creadas en BigQuery:")
    for table in tables:
        full_table = client.get_table(table.reference)
        logging.info(f"  ✓ {table.table_id}")
        logging.info(f"      Filas: {full_table.num_rows:,}")
        logging.info(f"      Tamaño: {full_table.num_bytes / (1024**2):.2f} MB")

    logging.info("\n" + "="*60)
    logging.info("¡CARGA COMPLETADA EXITOSAMENTE!")
    logging.info("="*60)
    logging.info("\nPróximos pasos:")
    logging.info("  1. Verificar datos en BigQuery Console")
    logging.info("  2. Ejecutar queries de análisis")
    logging.info("  3. Conectar Looker para dashboards")

if __name__ == "__main__":
    main()
