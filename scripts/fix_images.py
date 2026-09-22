"""
Obsidian writes image embeds as [[Pasted image 20260915.png]].
Hugo needs standard Markdown: ![Image Description](/images/Pasted%20image%2020260915.png)
This script rewrites the links in every post and copies the matching image
file into Hugo's static/images folder so it's served correctly.

Edit the three paths below to match your own setup, then run:
    python3 scripts/fix_images.py
"""

import os
import re
import shutil

# --- EDIT THESE THREE PATHS FOR YOUR OWN MACHINE ---
POSTS_DIR = "content/posts"
OBSIDIAN_ATTACHMENTS_DIR = "/home/strangertomyheart/Sync/Notebook/04 - Assets"
STATIC_IMAGES_DIR = "static/images"
# -----------------------------------------------------

os.makedirs(STATIC_IMAGES_DIR, exist_ok=True)

for filename in os.listdir(POSTS_DIR):
    if not filename.endswith(".md"):
        continue

    filepath = os.path.join(POSTS_DIR, filename)
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    images = re.findall(r"\[\[([^\]]*\.(?:png|jpg|jpeg|gif|webp))\]\]", content)

    for image in images:
        markdown_image = f"![Image Description](/images/{image.replace(' ', '%20')})"
        content = content.replace(f"[[{image}]]", markdown_image)

        source = os.path.join(OBSIDIAN_ATTACHMENTS_DIR, image)
        if os.path.exists(source):
            shutil.copy(source, STATIC_IMAGES_DIR)
        else:
            print(f"  warning: image not found, skipped copy: {image}")

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

print("Done: markdown files processed and images copied.")
