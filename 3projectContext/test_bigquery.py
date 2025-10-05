#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test de BigQuery - Validar datos y optimizaciones
"""

from google.cloud import bigquery
import pandas as pd

PROJECT_ID = "topicos-bases-datos"
DATASET_ID = "f1_data_warehouse"

def run_query(query, description):
    """Ejecutar query y mostrar resultados."""
    print("\n" + "="*60)
    print(f"TEST: {description}")
    print("="*60)

    client = bigquery.Client(project=PROJECT_ID)

    query_job = client.query(query)
    results = query_job.result()

    # Convertir a DataFrame para mejor visualización
    df = results.to_dataframe()

    print(f"\nResultados ({len(df)} filas):")
    print(df.to_string())

    # Info de bytes procesados
    bytes_processed = query_job.total_bytes_processed
    bytes_billed = query_job.total_bytes_billed

    print(f"\n📊 Estadísticas de la query:")
    print(f"  Bytes procesados: {bytes_processed / (1024**2):.2f} MB")
    print(f"  Bytes facturados: {bytes_billed / (1024**2):.2f} MB")
    print(f"  Tiempo: {query_job.ended - query_job.started}")

    return df

def main():
    print("="*60)
    print("TESTS DE BIGQUERY - F1 ANALYTICS")
    print("="*60)

    # Test 1: Datos básicos de Verstappen en Bahrain
    query1 = """
    SELECT
      Year,
      EventName,
      Country,
      Driver,
      Team,
      LapNumber,
      CAST(LapTime AS STRING) as LapTime,
      Compound
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE Driver = 'VER'
      AND Country = 'Bahrain'
      AND Year = 2024
    ORDER BY LapNumber
    LIMIT 10
    """
    run_query(query1, "Vueltas de Verstappen en Bahrain 2024")

    # Test 2: Verificar clustering fields
    query2 = """
    SELECT
      clustering_ordinal_position,
      column_name
    FROM `topicos-bases-datos.f1_data_warehouse.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = 'laps_enriched'
      AND clustering_ordinal_position IS NOT NULL
    ORDER BY clustering_ordinal_position
    """
    run_query(query2, "Clustering Fields Configurados")

    # Test 3: Verificar particionamiento
    query3 = """
    SELECT
      column_name,
      is_partitioning_column
    FROM `topicos-bases-datos.f1_data_warehouse.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = 'laps_enriched'
      AND is_partitioning_column = 'YES'
    """
    run_query(query3, "Partition Field Configurado")

    # Test 4: Query analítica - Eventos únicos por año
    query4 = """
    SELECT
      EventName,
      COUNT(DISTINCT Year) as years_count,
      STRING_AGG(DISTINCT CAST(Year AS STRING) ORDER BY Year) as years
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    GROUP BY EventName
    ORDER BY EventName
    LIMIT 15
    """
    run_query(query4, "Eventos Únicos (verifica que EventName se repite)")

    # Test 5: Performance query con clustering
    query5 = """
    SELECT
      Driver,
      Team,
      COUNT(*) as total_laps,
      ROUND(AVG(Sector1_Speed_Avg), 2) as avg_speed_s1,
      ROUND(AVG(Sector2_Speed_Avg), 2) as avg_speed_s2,
      ROUND(AVG(Sector3_Speed_Avg), 2) as avg_speed_s3
    FROM `topicos-bases-datos.f1_data_warehouse.laps_enriched`
    WHERE Country = 'Monaco'
      AND Year = 2024
      AND SessionName = 'Race'
    GROUP BY Driver, Team
    ORDER BY avg_speed_s1 DESC
    """
    run_query(query5, "Análisis de velocidad por sector - Monaco 2024")

    print("\n" + "="*60)
    print("✓ TODOS LOS TESTS COMPLETADOS")
    print("="*60)

if __name__ == "__main__":
    main()
