```bash
#!/usr/bin/env bash
set -euo pipefail

OBSIDIAN_PORTFOLIO_DIR="$HOME/Sync/Notebook/03 - Public/Portfolio"
PROFILE_SOURCE="$OBSIDIAN_PORTFOLIO_DIR/Profile.md"
PORTFOLIO_SOURCE="$OBSIDIAN_PORTFOLIO_DIR/Portfolio.md"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Check required commands.
for cmd in python3 hugo git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

# Check required Obsidian files.
for file in "$PROFILE_SOURCE" "$PORTFOLIO_SOURCE"; do
    if [[ ! -f "$file" ]]; then
        echo "Error: Required file not found:"
        echo "$file"
        exit 1
    fi
done

# Require the main branch and a clean working tree.
BRANCH="$(git branch --show-current)"
if [[ "$BRANCH" != "main" ]]; then
    echo "Error: Expected branch 'main', but currently on '$BRANCH'."
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: Your working tree has uncommitted changes."
    echo "Commit, stash, or otherwise resolve them before publishing."
    git status --short
    exit 1
fi

echo
echo "==> Combining Obsidian profile and portfolio..."

python3 - "$PROFILE_SOURCE" "$PORTFOLIO_SOURCE" "content/_index.md" <<'PY'
import json
import re
import sys
from pathlib import Path

profile_path, portfolio_path, output_path = map(Path, sys.argv[1:])

def read_properties(path):
    content = path.read_text(encoding="utf-8")
    parts = content.split("---", 2)

    if len(parts) < 3 or parts[0].strip():
        raise SystemExit(
            f"Error: {path.name} must begin with YAML properties "
            "between opening and closing --- lines."
        )

    properties = {}

    for line in parts[1].splitlines():
        line = line.strip()

        if not line or line.startswith("#"):
            continue

        match = re.match(
            r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*?)\s*$",
            line,
        )
        if not match:
            raise SystemExit(f"Error: Cannot read property line: {line}")

        key, value = match.groups()

        if value.startswith('"'):
            value = json.loads(value)
        elif value.startswith("'") and value.endswith("'"):
            value = value[1:-1].replace("''", "'")

        properties[key] = value

    return properties

profile = read_properties(profile_path)

required = ["name", "role", "description", "avatar", "linkedin", "github", "email"]
missing = [key for key in required if not profile.get(key)]

if missing:
    raise SystemExit(
        "Error: Missing Profile.md properties: " + ", ".join(missing)
    )

def yaml_string(value):
    return json.dumps(str(value), ensure_ascii=False)

front_matter = f"""---
dismissible: true
title: "Home"
author:
  name: {yaml_string(profile["name"])}
  title: {yaml_string(profile["role"])}
  description: {yaml_string(profile["description"])}
  avatar: {yaml_string(profile["avatar"])}
  social:
    - name: "LinkedIn"
      url: {yaml_string(profile["linkedin"])}
      icon: "linkedin"
    - name: "GitHub"
      url: {yaml_string(profile["github"])}
      icon: "github"
    - name: "Email"
      url: {yaml_string(profile["email"])}
      icon: "email"
---
"""

portfolio = portfolio_path.read_text(encoding="utf-8").strip()

if portfolio.startswith("---"):
    raise SystemExit(
        "Error: Portfolio.md should contain only Markdown, "
        "without YAML front matter."
    )

output_path.write_text(
    front_matter + "\n" + portfolio + "\n",
    encoding="utf-8",
)

print("Profile and portfolio combined successfully.")
PY

echo
echo "==> Building Hugo site..."
hugo --minify

echo
echo "==> Checking generated portfolio changes..."
git add content/_index.md

if git diff --cached --quiet -- content/_index.md; then
    echo "No portfolio content changes to publish."
    exit 0
fi

echo
echo "==> Committing portfolio update..."
git commit -m "Update portfolio"

echo
echo "==> Pushing to GitHub..."
git push origin "$BRANCH"

echo
echo "Portfolio pushed successfully!"
echo "GitHub Pages will deploy the update."
```
