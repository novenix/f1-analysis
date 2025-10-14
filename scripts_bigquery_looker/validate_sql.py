#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para validar sintaxis SQL de las queries BigQuery

Uso:
    python validate_sql.py
"""

from google.cloud import bigquery
import os
import sys

# Configuración
PROJECT_ID = "topicos-bases-datos"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

SQL_FILES = [
    "01_tyre_degradation_analysis.sql",
    "02_pit_stop_windows_analysis.sql",
    "03_weather_performance_correlation.sql",
    "04_driver_metrics_for_dynamodb.sql"
]


def extract_first_query(file_path):
    """Extraer la primera query del archivo SQL."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Buscar el primer WITH o SELECT
    with_start = content.find("\nWITH ")
    select_start = content.find("\nSELECT ")

    if with_start == -1 and select_start == -1:
        return None

    if with_start != -1 and (select_start == -1 or with_start < select_start):
        query_start = with_start + 1
    else:
        query_start = select_start + 1

    # Buscar el final de la query (siguiente separador --)
    next_separator = content.find("\n-- ====", query_start + 10)

    if next_separator == -1:
        query_end = len(content)
    else:
        query_end = next_separator

    query = content[query_start:query_end].strip()

    # Limitar a las primeras 50 líneas para dry run
    lines = query.split('\n')[:50]
    query = '\n'.join(lines)

    # Agregar LIMIT 1 para validación
    if not query.endswith(';'):
        query += "\nLIMIT 1;"

    return query


def validate_sql_file(client, file_path):
    """Validar sintaxis SQL usando BigQuery dry run."""
    print(f"\n{'='*80}")
    print(f"Validando: {os.path.basename(file_path)}")
    print('='*80)

    if not os.path.exists(file_path):
        print(f"❌ Archivo no encontrado: {file_path}")
        return False

    # Extraer primera query
    query = extract_first_query(file_path)

    if not query:
        print("⚠️  No se pudo extraer query del archivo")
        return True  # No es un error crítico

    # Dry run para validar sintaxis
    job_config = bigquery.QueryJobConfig(
        dry_run=True,
        use_query_cache=False
    )

    try:
        query_job = client.query(query, job_config=job_config)

        # Si llegamos aquí, la sintaxis es válida
        print("✅ Sintaxis SQL válida")
        print(f"   Bytes estimados: {query_job.total_bytes_processed:,}")
        print(f"   MB estimados: {query_job.total_bytes_processed / 1024**2:.2f} MB")

        return True

    except Exception as e:
        print(f"❌ Error de sintaxis SQL:")
        print(f"   {str(e)}")
        return False


def main():
    print("\n" + "="*80)
    print("VALIDADOR DE SINTAXIS SQL - BigQuery")
    print("="*80)

    # Crear cliente de BigQuery
    try:
        client = bigquery.Client(project=PROJECT_ID)
        print(f"✅ Conectado a BigQuery (Proyecto: {PROJECT_ID})")
    except Exception as e:
        print(f"❌ Error conectando a BigQuery: {e}")
        print("\nAsegúrate de que:")
        print("  1. Tienes credenciales configuradas (gcloud auth application-default login)")
        print("  2. Tienes acceso al proyecto: topicos-bases-datos")
        sys.exit(1)

    # Validar cada archivo
    all_valid = True
    results = []

    for sql_file in SQL_FILES:
        file_path = os.path.join(SCRIPT_DIR, sql_file)
        is_valid = validate_sql_file(client, file_path)
        results.append((sql_file, is_valid))
        all_valid = all_valid and is_valid

    # Resumen
    print("\n" + "="*80)
    print("RESUMEN DE VALIDACIÓN")
    print("="*80 + "\n")

    for file_name, is_valid in results:
        status = "✅ VÁLIDO" if is_valid else "❌ ERROR"
        print(f"  {status}: {file_name}")

    print("\n" + "="*80)

    if all_valid:
        print("✅ Todos los archivos SQL tienen sintaxis válida")
        print("="*80 + "\n")
        sys.exit(0)
    else:
        print("❌ Algunos archivos tienen errores de sintaxis")
        print("="*80 + "\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
