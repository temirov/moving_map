#!/bin/bash

# Step 1: Download fonts
mkdir -p /fonts
cd /fonts || exit

# Noto Sans
curl -LO https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf
curl -LO https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Bold.ttf
curl -LO https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Italic.ttf
curl -LO https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansSymbols/NotoSansSymbols-Regular.ttf

# Open Sans
curl -LO https://github.com/googlefonts/opensans/raw/main/fonts/ttf/OpenSans-Regular.ttf
curl -LO https://github.com/googlefonts/opensans/raw/main/fonts/ttf/OpenSans-Bold.ttf
curl -LO https://github.com/googlefonts/opensans/raw/main/fonts/ttf/OpenSans-Italic.ttf

# Roboto
curl -LO https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Regular.ttf
curl -LO https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Bold.ttf
curl -LO https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Italic.ttf

echo "Fonts downloaded successfully."
