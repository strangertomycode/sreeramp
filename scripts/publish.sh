#!/bin/bash
set -euo pipefail

# --- EDIT THIS ONE PATH FOR YOUR OWN MACHINE ---
OBSIDIAN_POSTS_DIR="/home/strangertomyheart/Sync/Maya/01 - Inbox/blog-posts"
# -------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."   # run from the Hugo site root

for cmd in git rsync python3 hugo; do
  if ! command -v $cmd &> /dev/null; then
    echo "$cmd is not installed or not in PATH."
    exit 1
  fi
done

echo "Syncing posts from Obsidian..."
mkdir -p content/posts
rsync -av --delete "$OBSIDIAN_POSTS_DIR/" content/posts/

echo "Fixing Obsidian-style image links..."
python3 scripts/fix_images.py

echo "Building the Hugo site locally (sanity check before pushing)..."
hugo --minify

echo "Staging and committing..."
git add -A
if git diff --cached --quiet; then
  echo "No changes to commit."
else
  git commit -m "New post on $(date +'%Y-%m-%d %H:%M:%S')"
fi

echo "Pushing to GitHub (this triggers the Actions deploy)..."
git push origin master

echo "Done. Check the Actions tab on GitHub to watch the deploy."