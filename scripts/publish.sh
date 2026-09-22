#!/bin/bash

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

OBSIDIAN_PUBLIC_DIR="/home/strangertomyheart/Sync/Notebook/01 - Inbox/public"

# ============================================================
# Setup
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# ============================================================
# Check required commands
# ============================================================

for cmd in git rsync python3 hugo; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

# ============================================================
# Check Obsidian source directory
# ============================================================

if [ ! -d "$OBSIDIAN_PUBLIC_DIR" ]; then
    echo "Error: Obsidian public directory not found:"
    echo "$OBSIDIAN_PUBLIC_DIR"
    exit 1
fi

# ============================================================
# Sync blog posts
# ============================================================

echo
echo "==> Syncing blog posts from Obsidian..."

mkdir -p content/posts

rsync -av --delete \
    "$OBSIDIAN_PUBLIC_DIR/blog-posts/" \
    content/posts/

# ============================================================
# Sync portfolio
# ============================================================

echo
echo "==> Syncing portfolio from Obsidian..."

PORTFOLIO_SOURCE="$OBSIDIAN_PUBLIC_DIR/Portfolio.md"
PORTFOLIO_DEST="content/_index.md"

if [ ! -f "$PORTFOLIO_SOURCE" ]; then
    echo "Error: Portfolio.md not found:"
    echo "$PORTFOLIO_SOURCE"
    exit 1
fi

python3 - "$PORTFOLIO_SOURCE" "$PORTFOLIO_DEST" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
destination = Path(sys.argv[2])

portfolio_content = source.read_text(encoding="utf-8")
existing = destination.read_text(encoding="utf-8")

parts = existing.split("---", 2)

if len(parts) != 3:
    raise SystemExit(
        "Error: Could not find valid Hugo front matter in content/_index.md"
    )

front_matter = parts[0] + "---" + parts[1] + "---"

destination.write_text(
    front_matter.rstrip() + "\n\n" + portfolio_content.lstrip(),
    encoding="utf-8",
)
PY

# ============================================================
# Sync About page
# ============================================================

echo
echo "==> Syncing About page from Obsidian..."

ABOUT_SOURCE="$OBSIDIAN_PUBLIC_DIR/About.md"
ABOUT_DEST="content/about/_index.md"

if [ ! -f "$ABOUT_SOURCE" ]; then
    echo "Error: About.md not found:"
    echo "$ABOUT_SOURCE"
    exit 1
fi

python3 - "$ABOUT_SOURCE" "$ABOUT_DEST" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
destination = Path(sys.argv[2])

about_content = source.read_text(encoding="utf-8")
existing = destination.read_text(encoding="utf-8")

parts = existing.split("---", 2)

if len(parts) != 3:
    raise SystemExit(
        "Error: Could not find valid Hugo front matter in "
        "content/about/_index.md"
    )

front_matter = parts[0] + "---" + parts[1] + "---"

destination.write_text(
    front_matter.rstrip() + "\n\n" + about_content.lstrip(),
    encoding="utf-8",
)
PY

# ============================================================
# Fix Obsidian image links
# ============================================================

echo
echo "==> Fixing Obsidian-style image links..."

python3 scripts/fix_images.py

# ============================================================
# Build Hugo site
# ============================================================

echo
echo "==> Building Hugo site..."

hugo --minify

echo
echo "==> Hugo build successful."

# ============================================================
# Git status
# ============================================================

echo
echo "==> Checking Git changes..."

if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
    echo "No changes detected."
    echo "Nothing to commit or push."
    exit 0
fi

# ============================================================
# Commit changes
# ============================================================

echo
echo "==> Staging changes..."

git add -A

if git diff --cached --quiet; then
    echo "No staged changes."
    echo "Nothing to commit or push."
    exit 0
fi

COMMIT_MESSAGE="Update site - $(date '+%Y-%m-%d %H:%M:%S')"

echo
echo "==> Creating commit..."
echo "    $COMMIT_MESSAGE"

git commit -m "$COMMIT_MESSAGE"

# ============================================================
# Push changes
# ============================================================

echo
echo "==> Pushing to GitHub..."

git push origin master

# ============================================================
# Done
# ============================================================

echo
echo "============================================================"
echo "Publishing complete."
echo "============================================================"
echo