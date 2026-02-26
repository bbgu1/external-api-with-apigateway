#!/bin/bash
# Build script for Lambda layer
# This script creates a Lambda layer zip file with all dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="${SCRIPT_DIR}/layer"
PYTHON_DIR="${LAYER_DIR}/python"

echo "Building Lambda layer..."

# Clean previous build
rm -rf "${LAYER_DIR}"
rm -f "${SCRIPT_DIR}/lambda-layer.zip"

# Create layer directory structure
mkdir -p "${PYTHON_DIR}"

# Install dependencies
echo "Installing dependencies..."
python3 -m pip install -r "${SCRIPT_DIR}/requirements.txt" -t "${PYTHON_DIR}" --upgrade

# Copy lambda_base.py module to layer
echo "Copying lambda_base.py module..."
cp "${SCRIPT_DIR}/lambda_base.py" "${PYTHON_DIR}/"

# Remove unnecessary files to reduce layer size
echo "Cleaning up unnecessary files..."
find "${PYTHON_DIR}" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
find "${PYTHON_DIR}" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "${PYTHON_DIR}" -name "*.pyc" -delete
find "${PYTHON_DIR}" -name "*.pyo" -delete
find "${PYTHON_DIR}" -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true

# Create zip file
echo "Creating layer zip file..."
cd "${LAYER_DIR}"
zip -r "${SCRIPT_DIR}/lambda-layer.zip" python -q

# Clean up build directory
cd "${SCRIPT_DIR}"
rm -rf "${LAYER_DIR}"

echo "Lambda layer built successfully: lambda-layer.zip"
echo "Layer size: $(du -h lambda-layer.zip | cut -f1)"
