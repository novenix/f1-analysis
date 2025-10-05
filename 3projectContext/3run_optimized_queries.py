#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ejecutar Queries Optimizadas de BigQuery y guardar resultados en TXT
"""

from google.cloud import bigquery
import re
from datetime import datetime

PROJECT_ID = "topicos-bases-datos"
DATASET_ID = "f1_data_warehouse"

def extract_queries_from_file(sql_file):
    """Extraer queries individuales del archivo SQL."""
    with open(sql_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Dividir por comentarios de patrón
    patterns = re.split(r'-- ={50,}\n-- PATRÓN \d+:', content)

    queries = []
    for i, section in enumerate(patterns[1:], 1):  # Saltar la intro
        # Extraer título del patrón
        title_match = re.search(r'^([^\n]+)', section)
        title = title_match.group(1).strip() if title_match else f"Query {i}"

        # Extraer la query SQL (todo entre SELECT y ;)
        query_matches = re.findall(r'(SELECT[\s\S]+?;)', section, re.MULTILINE)

        if query_matches:
            # Tomar la primera query del patrón (la principal, no las de anti-patrones)
            query = query_matches[0]

            # Limpiar comentarios inline
            query_lines = []
            for line in query.split('\n'):
                # Remover comentarios pero mantener la línea
                clean_line = re.sub(r'--.*$', '', line)
                if clean_line.strip():
                    query_lines.append(clean_line)

            clean_query = '\n'.join(query_lines)

            queries.append({
                'title': title,
                'query': clean_query
            })

    return queries

def run_query_and_format(client, query_info, query_num):
    """Ejecutar query y formatear resultados."""
    output = []

    output.append("=" * 80)
    output.append(f"QUERY #{query_num}: {query_info['title']}")
    output.append("=" * 80)
    output.append("")

    # Mostrar la query
    output.append("SQL Query:")
    output.append("-" * 80)
    output.append(query_info['query'])
    output.append("-" * 80)
    output.append("")

    try:
        # Ejecutar query
        query_job = client.query(query_info['query'])
        results = query_job.result()

        # Convertir a lista de diccionarios
        rows = [dict(row) for row in results]

        # Estadísticas
        bytes_processed = query_job.total_bytes_processed
        bytes_billed = query_job.total_bytes_billed
        duration = query_job.ended - query_job.started

        output.append("📊 Estadísticas de la Query:")
        output.append(f"  • Filas retornadas: {len(rows)}")
        output.append(f"  • Bytes procesados: {bytes_processed / (1024**2):.2f} MB")
        output.append(f"  • Bytes facturados: {bytes_billed / (1024**2):.2f} MB")
        output.append(f"  • Duración: {duration}")
        output.append("")

        # Resultados
        if rows:
            output.append("Resultados:")
            output.append("-" * 80)

            # Encabezados
            headers = list(rows[0].keys())
            header_line = " | ".join(str(h).ljust(15) for h in headers)
            output.append(header_line)
            output.append("-" * len(header_line))

            # Filas (limitar a 20 para legibilidad)
            for row in rows[:20]:
                values = [str(row.get(h, '')).ljust(15) for h in headers]
                output.append(" | ".join(values))

            if len(rows) > 20:
                output.append(f"... ({len(rows) - 20} filas adicionales omitidas)")
        else:
            output.append("Sin resultados.")

        output.append("")
        output.append("✅ Query ejecutada exitosamente")

    except Exception as e:
        output.append("❌ ERROR al ejecutar query:")
        output.append(str(e))

    output.append("")
    output.append("")

    return "\n".join(output)

def main():
    """Función principal."""
    print("=" * 80)
    print("EJECUTANDO QUERIES OPTIMIZADAS DE BIGQUERY")
    print("=" * 80)
    print("")

    # Crear cliente
    client = bigquery.Client(project=PROJECT_ID)

    # Extraer queries del archivo
    sql_file = '3projectContext/bigquery_queries_optimized.sql'
    print(f"Leyendo queries desde: {sql_file}")

    queries = extract_queries_from_file(sql_file)
    print(f"Queries encontradas: {len(queries)}")
    print("")

    # Archivo de salida
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f'3projectContext/bigquery_results_{timestamp}.txt'

    # Encabezado del archivo
    output_content = []
    output_content.append("=" * 80)
    output_content.append("RESULTADOS DE QUERIES OPTIMIZADAS - F1 ANALYTICS")
    output_content.append("=" * 80)
    output_content.append(f"Proyecto: {PROJECT_ID}")
    output_content.append(f"Dataset: {DATASET_ID}")
    output_content.append(f"Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    output_content.append(f"Total de queries: {len(queries)}")
    output_content.append("=" * 80)
    output_content.append("")
    output_content.append("")

    # Ejecutar cada query
    for i, query_info in enumerate(queries, 1):
        print(f"Ejecutando Query #{i}: {query_info['title']}...")

        result_text = run_query_and_format(client, query_info, i)
        output_content.append(result_text)

        # También imprimir en consola
        print(f"  ✓ Completada")
        print("")

    # Guardar a archivo
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("\n".join(output_content))

    print("=" * 80)
    print("✅ TODAS LAS QUERIES EJECUTADAS")
    print("=" * 80)
    print(f"Resultados guardados en: {output_file}")
    print("")

if __name__ == "__main__":
    main()
