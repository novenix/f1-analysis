#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para probar las queries de BigQuery desde Python

Uso:
    python test_queries.py --query 01.1
    python test_queries.py --query 02.2 --preview
    python test_queries.py --list
"""

from google.cloud import bigquery
import argparse
import sys
import os

# Configuración
PROJECT_ID = "topicos-bases-datos"
DATASET_ID = "f1_data_warehouse"

# Mapeo de queries
QUERIES = {
    "01.1": {
        "file": "01_tyre_degradation_analysis.sql",
        "section": "QUERY 1.1",
        "description": "Degradación de Neumáticos - Vista Principal"
    },
    "01.2": {
        "file": "01_tyre_degradation_analysis.sql",
        "section": "QUERY 1.2",
        "description": "Degradación Promedio por Compuesto y Circuito"
    },
    "01.3": {
        "file": "01_tyre_degradation_analysis.sql",
        "section": "QUERY 1.3",
        "description": "Análisis de Degradación por TyreLife Específico"
    },
    "01.4": {
        "file": "01_tyre_degradation_analysis.sql",
        "section": "QUERY 1.4",
        "description": "Top Equipos por Gestión de Neumáticos"
    },
    "02.1": {
        "file": "02_pit_stop_windows_analysis.sql",
        "section": "QUERY 2.1",
        "description": "Identificar Primera Parada de cada Piloto"
    },
    "02.2": {
        "file": "02_pit_stop_windows_analysis.sql",
        "section": "QUERY 2.2",
        "description": "Comparativa de Cohortes de Estrategia"
    },
    "02.3": {
        "file": "02_pit_stop_windows_analysis.sql",
        "section": "QUERY 2.3",
        "description": "Análisis de Undercut vs Overcut"
    },
    "02.4": {
        "file": "02_pit_stop_windows_analysis.sql",
        "section": "QUERY 2.4",
        "description": "Impacto de Estrategias de 1 vs 2 Paradas"
    },
    "02.5": {
        "file": "02_pit_stop_windows_analysis.sql",
        "section": "QUERY 2.5",
        "description": "Ventana Óptima de Parada por Circuito"
    },
    "03.1": {
        "file": "03_weather_performance_correlation.sql",
        "section": "QUERY 3.1",
        "description": "Correlación Temperatura vs Tiempo de Vuelta"
    },
    "03.2": {
        "file": "03_weather_performance_correlation.sql",
        "section": "QUERY 3.2",
        "description": "Análisis de Correlación por Circuito"
    },
    "03.3": {
        "file": "03_weather_performance_correlation.sql",
        "section": "QUERY 3.3",
        "description": "Impacto de Temperatura por Compuesto"
    },
    "03.4": {
        "file": "03_weather_performance_correlation.sql",
        "section": "QUERY 3.4",
        "description": "Análisis de Sectores bajo Condiciones de Viento"
    },
    "03.5": {
        "file": "03_weather_performance_correlation.sql",
        "section": "QUERY 3.5",
        "description": "Predictor de Performance basado en Condiciones"
    },
    "04.1": {
        "file": "04_driver_metrics_for_dynamodb.sql",
        "section": "QUERY 4.1",
        "description": "Tyre Management Index"
    },
    "04.2": {
        "file": "04_driver_metrics_for_dynamodb.sql",
        "section": "QUERY 4.2",
        "description": "Consistency Score"
    },
    "04.3": {
        "file": "04_driver_metrics_for_dynamodb.sql",
        "section": "QUERY 4.3",
        "description": "Sector Performance Profile"
    },
    "04.4": {
        "file": "04_driver_metrics_for_dynamodb.sql",
        "section": "QUERY 4.4",
        "description": "Perfil Consolidado de Piloto (Para DynamoDB)"
    }
}


def extract_query_from_file(file_path, section_marker):
    """
    Extraer una query específica del archivo SQL.

    Args:
        file_path: Ruta al archivo SQL
        section_marker: Marcador de sección (ej: "QUERY 1.1")

    Returns:
        str: Texto de la query SQL
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Buscar el marcador de sección
    section_start = content.find(f"-- {section_marker}:")

    if section_start == -1:
        raise ValueError(f"No se encontró la sección {section_marker} en {file_path}")

    # Buscar el inicio de la query (después de la descripción)
    # Las queries empiezan después de los comentarios de descripción
    query_start = content.find("WITH", section_start)
    if query_start == -1:
        query_start = content.find("SELECT", section_start)

    if query_start == -1:
        raise ValueError(f"No se encontró el inicio de la query en {section_marker}")

    # Buscar el final de la query (siguiente sección con --)
    next_section = content.find("\n-- =====", query_start + 1)

    if next_section == -1:
        query_end = len(content)
    else:
        query_end = next_section

    query = content[query_start:query_end].strip()

    return query


def list_queries():
    """Listar todas las queries disponibles."""
    print("\n" + "="*80)
    print("QUERIES DISPONIBLES")
    print("="*80 + "\n")

    current_file = None

    for query_id, info in sorted(QUERIES.items()):
        if info['file'] != current_file:
            current_file = info['file']
            print(f"\n📄 {current_file}")
            print("-" * 80)

        print(f"  {query_id}: {info['description']}")

    print("\n" + "="*80)
    print("\nUso: python test_queries.py --query <ID>")
    print("Ejemplo: python test_queries.py --query 01.1 --limit 10")
    print("="*80 + "\n")


def run_query(query_id, preview=False, limit=None, dry_run=False):
    """
    Ejecutar una query de BigQuery.

    Args:
        query_id: ID de la query (ej: "01.1")
        preview: Si True, solo muestra la query sin ejecutar
        limit: Limitar resultados
        dry_run: Si True, solo calcula bytes procesados sin ejecutar
    """
    if query_id not in QUERIES:
        print(f"❌ Error: Query ID '{query_id}' no encontrado.")
        print(f"   Usa --list para ver queries disponibles.")
        sys.exit(1)

    query_info = QUERIES[query_id]

    print("\n" + "="*80)
    print(f"EJECUTANDO QUERY: {query_id}")
    print("="*80)
    print(f"Descripción: {query_info['description']}")
    print(f"Archivo: {query_info['file']}")
    print("="*80 + "\n")

    # Construir ruta al archivo
    script_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(script_dir, query_info['file'])

    if not os.path.exists(file_path):
        print(f"❌ Error: Archivo no encontrado: {file_path}")
        sys.exit(1)

    # Extraer query
    try:
        query_sql = extract_query_from_file(file_path, query_info['section'])
    except Exception as e:
        print(f"❌ Error extrayendo query: {e}")
        sys.exit(1)

    # Agregar LIMIT si se especifica
    if limit:
        query_sql = f"{query_sql}\nLIMIT {limit}"

    # Modo preview: solo mostrar la query
    if preview:
        print("📝 QUERY SQL:\n")
        print(query_sql)
        print("\n" + "="*80 + "\n")
        return

    # Crear cliente de BigQuery
    try:
        client = bigquery.Client(project=PROJECT_ID)
        print(f"✅ Conectado a BigQuery (Proyecto: {PROJECT_ID})\n")
    except Exception as e:
        print(f"❌ Error conectando a BigQuery: {e}")
        sys.exit(1)

    # Configurar job
    job_config = bigquery.QueryJobConfig()

    if dry_run:
        job_config.dry_run = True
        job_config.use_query_cache = False

    # Ejecutar query
    try:
        print("⏳ Ejecutando query...\n")

        query_job = client.query(query_sql, job_config=job_config)

        if dry_run:
            # Dry run: mostrar bytes procesados
            print("📊 DRY RUN - Estadísticas:")
            print(f"   Bytes a procesar: {query_job.total_bytes_processed:,}")
            print(f"   MB a procesar: {query_job.total_bytes_processed / 1024**2:.2f} MB")
            print(f"   GB a procesar: {query_job.total_bytes_processed / 1024**3:.4f} GB")
            print(f"   Costo estimado: ${query_job.total_bytes_processed / 1024**4 * 5:.6f} USD")
            print("\n   (Los primeros 1 TB al mes son gratis)")
        else:
            # Ejecutar y obtener resultados
            results = query_job.result()

            print("✅ Query ejecutada exitosamente!\n")
            print("📊 Estadísticas:")
            print(f"   Filas retornadas: {results.total_rows:,}")
            print(f"   Bytes procesados: {query_job.total_bytes_processed:,}")
            print(f"   MB procesados: {query_job.total_bytes_processed / 1024**2:.2f} MB")
            print(f"   Tiempo: {query_job.ended - query_job.started}")

            # Mostrar muestra de resultados
            print("\n📋 Muestra de resultados (primeras 10 filas):\n")

            # Obtener nombres de columnas
            schema = results.schema
            col_names = [field.name for field in schema]

            # Header
            header = " | ".join(col_names[:5])  # Primeras 5 columnas
            print(header)
            print("-" * len(header))

            # Datos
            for i, row in enumerate(results):
                if i >= 10:
                    break

                row_data = []
                for j, field in enumerate(schema[:5]):
                    value = row[j]
                    if value is None:
                        row_data.append("NULL")
                    elif isinstance(value, float):
                        row_data.append(f"{value:.2f}")
                    else:
                        row_data.append(str(value)[:20])

                print(" | ".join(row_data))

            if results.total_rows > 10:
                print(f"\n... y {results.total_rows - 10:,} filas más")

        print("\n" + "="*80 + "\n")

    except Exception as e:
        print(f"❌ Error ejecutando query: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Script para probar queries de BigQuery",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:

  # Listar todas las queries disponibles
  python test_queries.py --list

  # Ver una query sin ejecutar
  python test_queries.py --query 01.1 --preview

  # Ejecutar query con límite de resultados
  python test_queries.py --query 01.1 --limit 100

  # Dry run (calcular bytes procesados sin ejecutar)
  python test_queries.py --query 01.1 --dry-run

  # Ejecutar query completa
  python test_queries.py --query 04.4
        """
    )

    parser.add_argument(
        '--query',
        type=str,
        help='ID de la query a ejecutar (ej: 01.1, 02.3, etc.)'
    )

    parser.add_argument(
        '--list',
        action='store_true',
        help='Listar todas las queries disponibles'
    )

    parser.add_argument(
        '--preview',
        action='store_true',
        help='Mostrar la query sin ejecutarla'
    )

    parser.add_argument(
        '--limit',
        type=int,
        help='Limitar número de resultados'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Calcular bytes procesados sin ejecutar'
    )

    args = parser.parse_args()

    # Validar argumentos
    if args.list:
        list_queries()
        sys.exit(0)

    if not args.query:
        parser.print_help()
        print("\n❌ Error: Debes especificar --query o --list")
        sys.exit(1)

    # Ejecutar query
    run_query(
        query_id=args.query,
        preview=args.preview,
        limit=args.limit,
        dry_run=args.dry_run
    )


if __name__ == "__main__":
    main()
