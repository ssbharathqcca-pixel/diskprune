#!/bin/bash
set -e

echo "Building DiskPrune Native App..."
cd app
swift build
cd ..

echo "Building DiskPrune Web (Astro)..."
cd web
npm install
npm run build
cd ..

echo "Build and verification complete!"
