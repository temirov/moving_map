# Base image
FROM node:14 as font-conversion

# Install fontnik for TTF to PBF conversion
RUN npm install -g fontnik

# Create the /fonts directory
RUN mkdir -p /fonts

# Copy the font download script
COPY download-fonts.sh /usr/local/bin/download-fonts.sh
RUN chmod +x /usr/local/bin/download-fonts.sh

# Copy the font conversion script
COPY convert-fonts.sh /usr/local/bin/convert-fonts.sh
RUN chmod +x /usr/local/bin/convert-fonts.sh

# Download and convert fonts
RUN /usr/local/bin/download-fonts.sh && /usr/local/bin/convert-fonts.sh

# Stage 2: TileServer GL
FROM maptiler/tileserver-gl

# Copy converted fonts from the first stage
COPY --from=font-conversion /fonts /fonts
