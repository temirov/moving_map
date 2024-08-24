#!/bin/bash

# Convert TTF to PBF using fontnik
for font in /fonts/*.ttf; do
  fontname=$(basename "$font" .ttf)
  mkdir -p /fonts/$fontname
  echo "Converting $font to PBF glyphs..."
  
  # Generate PBF glyphs using fontnik
  build-glyphs "$font" /fonts/$fontname

  echo "Converted $font to PBF glyphs."
done

echo "All fonts converted."
