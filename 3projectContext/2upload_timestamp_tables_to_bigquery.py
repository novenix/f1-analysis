#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Subir Tablas con Timestamps Corregidos a BigQuery

Este script:
1. Detecta archivos *_timestamp.csv generados por el script de corrección
2. Elimina las tablas existentes en BigQuery
3. Sube las tablas con timestamps corregidos
4. Aplica particionamiento y clustering según corresponda

TABLAS A ACTUALIZAR:
- laps_enriched (particionada por EventDate, clustered por Driver, EventName, Country)
- results (clustered por Abbreviation, EventName, Year)
- weather (clustered por EventName, Year, SessionName)
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

# Mapeo de archivos a tablas en BigQuery
TABLE_CONFIG = {
    "laps_enriched": {
        "file_pattern": "laps_{year}_enriched_final_timestamp.csv",
        "partition_field": "EventDate",
        "cluster_fields": ["Driver", "EventName", "Country"],
        "description": "Tabla principal con telemetría y timestamps corregidos"
    },
    "results": {
        "file_pattern": "results_{year}_timestamp.csv",
        "partition_field": None,
        "cluster_fields": ["Abbreviation", "EventName", "Year"],
        "description": "Resultados de sesiones con timestamps corregidos"
    },
    "weather": {
        "file_pattern": "weather_{year}_timestamp.csv",
        "partition_field": None,
        "cluster_fields": ["EventName", "Year", "SessionName"],
        "description": "Datos meteorológicos con timestamps corregidos"
    }
}

def setup_logging():
    """Configurar logging."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('upload_timestamp_tables.log'),
            logging.StreamHandler()
        ]
    )

def get_bigquery_client():
    """Crear cliente de BigQuery."""
    client = bigquery.Client(project=PROJECT_ID)
    logging.info(f"Cliente de BigQuery creado para proyecto: {PROJECT_ID}")
    return client

def delete_table_if_exists(client, table_id):
    """
    Eliminar tabla si existe.

    Args:
        client: Cliente de BigQuery
        table_id: ID completo de la tabla

    Returns:
        bool: True si se eliminó la tabla
    """
    try:
        client.delete_table(table_id)
        logging.info(f"  ✓ Tabla eliminada: {table_id}")
        return True
    except NotFound:
        logging.info(f"  ℹ Tabla no existe: {table_id}")
        return False

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
        skip_leading_rows=1,
        autodetect=True,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE
    )

    # Particionamiento
    if partition_field:
        job_config.time_partitioning = bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field=partition_field
        )

    # Clustering
    if cluster_fields:
        job_config.clustering_fields = cluster_fields

    # Cargar archivo
    with open(csv_path, "rb") as source_file:
        job = client.load_table_from_file(source_file, table_id, job_config=job_config)

    job.result()

    # Info de la tabla
    table = client.get_table(table_id)
    logging.info(f"  ✓ Cargado: {csv_path}")
    logging.info(f"      Filas: {table.num_rows:,}")
    logging.info(f"      Tamaño: {table.num_bytes / (1024**2):.2f} MB")

def append_csv_to_bigquery(client, table_id, csv_path):
    """
    Añadir CSV a tabla existente usando su schema.

    Args:
        client: Cliente de BigQuery
        table_id: ID completo de la tabla
        csv_path: Ruta al archivo CSV
    """
    existing_table = client.get_table(table_id)

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        schema=existing_table.schema,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND
    )

    with open(csv_path, "rb") as source_file:
        job = client.load_table_from_file(source_file, table_id, job_config=job_config)

    job.result()
    logging.info(f"  ✓ Añadido: {csv_path}")

def upload_table_to_bigquery(client, table_name, config):
    """
    Subir tabla a BigQuery eliminando la existente y cargando datos nuevos.

    Args:
        client: Cliente de BigQuery
        table_name: Nombre de la tabla
        config: Configuración de la tabla (file_pattern, partition, cluster)

    Returns:
        bool: True si se procesó correctamente
    """
    logging.info("\\n" + "="*70)
    logging.info(f"PROCESANDO TABLA: {table_name}")
    logging.info("="*70)
    logging.info(f"Descripción: {config['description']}")

    if config['partition_field']:
        logging.info(f"Particionamiento: {config['partition_field']}")
    if config['cluster_fields']:
        logging.info(f"Clustering: {config['cluster_fields']}")

    logging.info("")

    table_id = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"

    # Verificar si existen archivos timestamp para esta tabla
    files_found = []
    for year in YEARS:
        csv_file = os.path.join(DATA_LAKE_DIR, str(year), config['file_pattern'].format(year=year))
        if os.path.exists(csv_file):
            files_found.append((year, csv_file))

    if not files_found:
        logging.warning(f"⚠️  No se encontraron archivos *_timestamp.csv para {table_name}")
        return False

    logging.info(f"Archivos encontrados: {len(files_found)}")

    # Eliminar tabla existente
    delete_table_if_exists(client, table_id)

    # Cargar datos año por año
    for i, (year, csv_file) in enumerate(files_found):
        logging.info(f"\\n  Cargando año {year}...")

        if i == 0:
            # Primera carga: crear tabla con configuración
            load_csv_to_bigquery(
                client,
                table_id,
                csv_file,
                partition_field=config['partition_field'],
                cluster_fields=config['cluster_fields']
            )
        else:
            # Cargas siguientes: APPEND
            append_csv_to_bigquery(client, table_id, csv_file)

    # Verificar tabla final
    table = client.get_table(table_id)

    logging.info(f"\\n  {'='*60}")
    logging.info(f"  TABLA COMPLETADA: {table_name}")
    logging.info(f"  {'='*60}")
    logging.info(f"  Total filas: {table.num_rows:,}")
    logging.info(f"  Tamaño: {table.num_bytes / (1024**2):.2f} MB")

    if table.time_partitioning:
        logging.info(f"  ✅ Particionada por: {table.time_partitioning.field}")

    if table.clustering_fields:
        logging.info(f"  ✅ Clustering: {table.clustering_fields}")

    return True

def verify_schema(client):
    """
    Verificar que los campos TIME se hayan cargado correctamente.

    Args:
        client: Cliente de BigQuery
    """
    logging.info("\\n" + "="*70)
    logging.info("VERIFICACIÓN DE SCHEMAS")
    logging.info("="*70)

    # Campos TIME esperados por tabla
    expected_time_fields = {
        "laps_enriched": [
            "Time", "LapTime", "PitOutTime", "PitInTime",
            "Sector1Time", "Sector2Time", "Sector3Time",
            "Sector1SessionTime", "Sector2SessionTime", "Sector3SessionTime",
            "LapStartTime",
            "Sector1_Throttle_100_Time", "Sector1_Brake_Time", "Sector1_Throttle_Time", "Sector1_Coasting_Time",
            "Sector2_Throttle_100_Time", "Sector2_Brake_Time", "Sector2_Throttle_Time", "Sector2_Coasting_Time",
            "Sector3_Throttle_100_Time", "Sector3_Brake_Time", "Sector3_Throttle_Time", "Sector3_Coasting_Time"
        ],
        "results": ["Time"],
        "weather": ["Time"]
    }

    for table_name, expected_fields in expected_time_fields.items():
        table_id = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"

        try:
            table = client.get_table(table_id)

            logging.info(f"\\n{table_name}:")
            logging.info(f"  Filas: {table.num_rows:,}")

            # Verificar tipos de campos TIME
            time_fields = [field for field in table.schema if field.name in expected_fields]

            logging.info(f"  Campos TIME detectados: {len(time_fields)}/{len(expected_fields)}")

            # Contar por tipo
            types_count = {}
            for field in time_fields:
                field_type = field.field_type
                types_count[field_type] = types_count.get(field_type, 0) + 1

                # Advertir si no es STRING (BigQuery auto-detecta como STRING si tiene formato TIME)
                # pero debería detectarse como STRING con formato HH:MM:SS
                logging.info(f"    - {field.name}: {field.field_type}")

            if len(time_fields) == len(expected_fields):
                logging.info(f"  ✅ Todos los campos TIME presentes")
            else:
                missing = set(expected_fields) - {f.name for f in time_fields}
                logging.warning(f"  ⚠️  Campos faltantes: {missing}")

        except NotFound:
            logging.error(f"  ❌ Tabla no encontrada: {table_name}")

def main():
    """Función principal."""
    setup_logging()

    logging.info("="*70)
    logging.info("SUBIR TABLAS CON TIMESTAMPS CORREGIDOS A BIGQUERY")
    logging.info("="*70)
    logging.info(f"Proyecto: {PROJECT_ID}")
    logging.info(f"Dataset: {DATASET_ID}")
    logging.info(f"Años: {YEARS}")
    logging.info("")
    logging.info("Tablas a actualizar:")
    for table_name, config in TABLE_CONFIG.items():
        logging.info(f"  • {table_name}")
    logging.info("")
    logging.info("⚠️  ADVERTENCIA: Las tablas existentes serán eliminadas y recreadas")
    logging.info("")

    # Crear cliente
    client = get_bigquery_client()

    # Procesar cada tabla
    results = {}
    for table_name, config in TABLE_CONFIG.items():
        success = upload_table_to_bigquery(client, table_name, config)
        results[table_name] = success

    # Verificar schemas
    verify_schema(client)

    # Resumen final
    logging.info("\\n" + "="*70)
    logging.info("RESUMEN FINAL")
    logging.info("="*70)

    successful = [name for name, success in results.items() if success]
    failed = [name for name, success in results.items() if not success]

    logging.info(f"\\nTablas procesadas: {len(successful)}/{len(results)}")

    if successful:
        logging.info("\\nTablas actualizadas exitosamente:")
        for table_name in successful:
            logging.info(f"  ✓ {table_name}")

    if failed:
        logging.info("\\nTablas NO procesadas:")
        for table_name in failed:
            logging.info(f"  ✗ {table_name}")

    logging.info("\\n" + "="*70)
    if len(successful) == len(results):
        logging.info("✅ TODAS LAS TABLAS ACTUALIZADAS EXITOSAMENTE")
    else:
        logging.info("⚠️  PROCESO COMPLETADO CON ADVERTENCIAS")
    logging.info("="*70)

    logging.info("\\nPróximos pasos:")
    logging.info("  1. Verificar tipos de datos en BigQuery Console")
    logging.info("  2. Ejecutar queries de prueba")
    logging.info("  3. Los campos TIME deberían mostrarse como STRING con formato HH:MM:SS")
    logging.info("  4. Usar PARSE_TIME() o TIME() en queries para convertir a tipo TIME")

if __name__ == "__main__":
    main()
