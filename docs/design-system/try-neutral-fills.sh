#!/usr/bin/env bash
# Try the neutral-fills trial on your own machine, over the real webapp on mock data (no backend).
#
# Run from the root of your novee checkout, on a clean main:
#   bash /path/to/try-neutral-fills.sh            # host mode: Next.js on http://localhost:3000
#   MODE=docker bash /path/to/try-neutral-fills.sh   # the repo's own task (needs Docker)
#
# Needs GITHUB_TOKEN and FONTAWESOME_PACKAGE_TOKEN (the same ones `task setup` puts in .env).
# Nothing is committed or pushed. To undo: git checkout main && git branch -D try/neutral-state-fills
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$HERE/neutral-fills-trial.patch"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

[ -f "$PATCH" ] || { echo "neutral-fills-trial.patch must sit next to this script"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Working tree is not clean. Stash or commit first."; exit 1; }

git checkout -b try/neutral-state-fills
git apply "$PATCH"
echo "Patch applied (theme.css, sidebar.tsx, DataGridRow.tsx, InfoBanner.tsx)."

if [ "${MODE:-host}" = "docker" ]; then
  exec task dev:frontend-mock FIXED_PORTS=true   # http://localhost:3000
fi

# Host mode. Same steps the docker builders run, once.
pnpm install --filter "@novee/webapp..."
( cd models/proto/clients/nodejs && pnpm build )          # @novee-io/contracts
( cd models && pnpm build:ts )                            # @novee/models (enum-groups)
( cd packages/api-shared && pnpm build:targets && pnpm build:esm:targets \
    && pnpm build:private-connections && pnpm build:esm:private-connections \
    && pnpm build:assessment-status && pnpm build:esm:assessment-status )
( cd backend/services/platform-service/api-ts && pnpm build )
( cd frontend/packages/api && pnpm build )                # @novee/webapp-api
( cd frontend/packages/ui && pnpm build )                 # @novee/ui, with the patch

cd frontend/packages/webapp
export APP_ENV=local NEXT_PUBLIC_ENABLE_MSW=true NEXT_PUBLIC_MOCK_AUTH=true \
       NEXT_PUBLIC_PROXY_URL=http://127.0.0.1:9 PORT=3000
echo "Open http://localhost:3000/issues  (select a few rows, hover others, toggle dark mode)"
exec pnpm dev
