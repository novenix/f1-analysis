#!/bin/bash
# Optimizar filtro de TrackStatus para mejor contexto de negocio

echo "Optimizing TrackStatus filter..."

# Cambiar de IN (1, 124) a < 4 (más correcto para análisis de degradación)
# Esto incluye solo Green (1) y Yellow (2), excluye Safety Car (4+)

sed -i '' 's/AND TrackStatus IN (1, 124)  -- Solo pista verde o AllClear/AND TrackStatus < 4  -- Green (1) o Yellow (2), excluye Safety Car/g' *.sql

sed -i '' 's/AND TrackStatus IN (1, 124)/AND TrackStatus < 4  -- Excluye Safety Car, VSC, Red Flag/g' *.sql

echo "Done! Verifying changes..."
grep -n "TrackStatus <" 01_tyre_degradation_analysis.sql | head -3
