#!/bin/bash
# Script para corregir tipos de datos en queries

echo "Fixing data types in SQL files..."

# 1. TrackStatus: Cambiar de STRING a INT64
echo "1. Fixing TrackStatus (STRING -> INT64)..."
sed -i '' "s/CAST(TrackStatus AS STRING) IN ('\([0-9]*\)', '\([0-9]*\)')/TrackStatus IN (\1, \2)/g" *.sql
sed -i '' "s/CAST(TrackStatus AS STRING) IN ('\([0-9]*\)')/TrackStatus IN (\1)/g" *.sql

# 2. Verificar cambios
echo "2. Verifying changes..."
grep -n "TrackStatus IN" 01_tyre_degradation_analysis.sql | head -3

echo "Done!"
