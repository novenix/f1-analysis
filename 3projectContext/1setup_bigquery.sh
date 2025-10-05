#!/bin/bash
# Setup de BigQuery para Proyecto F1 Analytics
# Este script configura el proyecto de Google Cloud y crea el dataset de BigQuery

set -e  # Exit on error

echo "========================================"
echo "SETUP DE BIGQUERY - F1 ANALYTICS PROJECT"
echo "========================================"
echo ""

# Variables de configuración
PROJECT_ID="topicos-bases-datos"  # Tu proyecto actual
DATASET_ID="f1_data_warehouse"
LOCATION="US"

# Paso 1: Autenticación
echo "Paso 1: Autenticación con Google Cloud"
echo "Se abrirá tu navegador para autenticarte..."
echo ""
gcloud auth login

# Paso 2: Configurar proyecto
echo ""
echo "Paso 2: Configurando proyecto..."
gcloud config set project $PROJECT_ID

# Paso 3: Habilitar BigQuery API
echo ""
echo "Paso 3: Habilitando BigQuery API..."
gcloud services enable bigquery.googleapis.com

# Paso 4: Crear dataset
echo ""
echo "Paso 4: Creando dataset '$DATASET_ID' en región '$LOCATION'..."
bq mk --dataset --location=$LOCATION $PROJECT_ID:$DATASET_ID || echo "Dataset ya existe, continuando..."

# Paso 5: Verificar dataset
echo ""
echo "Paso 5: Verificando dataset creado..."
bq ls --project_id=$PROJECT_ID

echo ""
echo "========================================"
echo "✓ SETUP COMPLETADO"
echo "========================================"
echo ""
echo "Información del setup:"
echo "  Proyecto: $PROJECT_ID"
echo "  Dataset: $DATASET_ID"
echo "  Ubicación: $LOCATION"
echo ""
echo "Próximo paso: Cargar datos con load_data_to_bigquery.py"
echo ""
