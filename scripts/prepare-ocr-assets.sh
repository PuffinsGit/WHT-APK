#!/usr/bin/env bash
set -euo pipefail

mkdir -p wht/ocr/core wht/ocr/lang

install -m 0644 node_modules/tesseract.js/dist/tesseract.min.js wht/ocr/tesseract.min.js
install -m 0644 node_modules/tesseract.js/dist/worker.min.js wht/ocr/worker.min.js
install -m 0644 node_modules/tesseract.js-core/tesseract-core.wasm.js wht/ocr/core/tesseract-core.wasm.js
install -m 0644 node_modules/tesseract.js-core/tesseract-core-simd.wasm.js wht/ocr/core/tesseract-core-simd.wasm.js
install -m 0644 node_modules/tesseract.js-core/tesseract-core-lstm.wasm.js wht/ocr/core/tesseract-core-lstm.wasm.js
install -m 0644 node_modules/tesseract.js-core/tesseract-core-simd-lstm.wasm.js wht/ocr/core/tesseract-core-simd-lstm.wasm.js
install -m 0644 node_modules/@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz wht/ocr/lang/eng.traineddata.gz

echo "Prepared the offline WHT photo-import OCR engine."
