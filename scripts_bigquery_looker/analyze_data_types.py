#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Analizar tipos de datos inferidos por BigQuery
"""

import pandas as pd

# Leer muestra del CSV
csv_path = "../f1_data_lake_focused/2021/laps_2021_enriched_final_timestamp.csv"
df = pd.read_csv(csv_path, nrows=1000)

print("="*80)
print("ANÁLISIS DE TIPOS DE DATOS - laps_enriched")
print("="*80)

# Campos clave a analizar
key_fields = [
    'TrackStatus', 'Position', 'Deleted', 'Year', 'Stint', 'TyreLife',
    'LapNumber', 'DriverNumber', 'IsPersonalBest', 'FreshTyre',
    'Sector1_nGear_Max', 'Sector1_nGear_Min'
]

for field in key_fields:
    if field in df.columns:
        dtype = df[field].dtype
        sample = df[field].dropna().head(5).tolist()
        unique = df[field].nunique()

        # Inferir tipo de BigQuery
        if dtype == 'object':
            bq_type = "STRING"
        elif dtype == 'bool':
            bq_type = "BOOLEAN"
        elif dtype == 'int64':
            bq_type = "INT64"
        elif dtype == 'float64':
            # Si todos son .0, podría ser INT64
            if df[field].dropna().apply(lambda x: x == int(x)).all():
                bq_type = "INT64 (cargado como FLOAT64)"
            else:
                bq_type = "FLOAT64"
        else:
            bq_type = str(dtype)

        print(f"\n{field}:")
        print(f"  Pandas dtype: {dtype}")
        print(f"  BigQuery type (inferido): {bq_type}")
        print(f"  Valores únicos: {unique}")
        print(f"  Muestra: {sample}")
