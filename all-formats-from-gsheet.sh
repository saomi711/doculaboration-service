#!/usr/bin/env bash
# gsheet->json->odt/docx/pdf pipeline - generates all formats

# parameters
DOCUMENT=$1

if [ -z "$DOCUMENT" ]; then
    echo "Error: Document name is required"
    echo "Usage: $0 <document_name>"
    exit 1
fi

# set echo off
PYTHON=python3

echo "Starting document processing for: $DOCUMENT"
echo "============================================"

# Step 1: json-from-gsheet
echo "Step 1/4: Generating JSON from Google Sheet..."
pushd ./gsheet-to-json/src
${PYTHON} json-from-gsheet.py --config "../conf/config.yml" --gsheet ${DOCUMENT}

if [ ${?} -ne 0 ]; then
  echo "Error: Failed to generate JSON from Google Sheet"
  popd && exit 1
else
  echo "✓ JSON generation completed"
  popd
fi

# Step 2: odt-from-json
echo "Step 2/4: Generating ODT from JSON..."
pushd ./json-to-odt/src
${PYTHON} odt-from-json.py --config "../conf/config.yml" --json ${DOCUMENT}

if [ ${?} -ne 0 ]; then
  echo "Error: Failed to generate ODT from JSON"
  popd && exit 1
else
  echo "✓ ODT generation completed"
  popd
fi

# Step 3: docx-from-json
echo "Step 3/4: Generating DOCX from JSON..."
pushd ./json-to-docx/src
${PYTHON} docx-from-json.py --config "../conf/config.yml" --json ${DOCUMENT}

if [ ${?} -ne 0 ]; then
  echo "Error: Failed to generate DOCX from JSON"
  popd && exit 1
else
  echo "✓ DOCX generation completed"
  popd
fi

# Step 4: pdf-from-odt (using LibreOffice)
echo "Step 4/4: Generating PDF from ODT..."
ODT_FILE="out/${DOCUMENT}.odt"
PDF_FILE="out/${DOCUMENT}.odt.pdf"

if [ -f "$ODT_FILE" ]; then
    # Use LibreOffice to convert ODT to PDF
    libreoffice --headless --convert-to pdf --outdir out "$ODT_FILE"
    
    if [ ${?} -ne 0 ]; then
        echo "Error: Failed to generate PDF from ODT"
        exit 1
    else
        echo "✓ PDF generation completed"
    fi
else
    echo "Error: ODT file not found: $ODT_FILE"
    exit 1
fi

echo ""
echo "Document processing completed successfully!"
echo "Generated files:"
echo "  - JSON: out/${DOCUMENT}.json"
echo "  - ODT:  out/${DOCUMENT}.odt"
echo "  - DOCX: out/${DOCUMENT}.docx"
echo "  - PDF:  out/${DOCUMENT}.odt.pdf"
echo "============================================"