#!/bin/bash
# Build and deploy the landing site directly to the linked Vercel project.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/web"

if [ ! -d node_modules ]; then
    npm ci
fi

npm run build
npx vercel deploy --prod
