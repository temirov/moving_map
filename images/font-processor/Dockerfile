# Use a Python base image
FROM python:3.9-slim AS font-processor

# Install font processing tools and dependencies
RUN apt-get update && apt-get install -y curl

# Set up working directory
WORKDIR /fonts

# Install fonttools
RUN pip install fonttools brotli

# Download Noto Sans font
RUN curl -L https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf -o NotoSans-Regular.ttf

# Convert TTF to WOFF2
RUN python -m fontTools.ttLib -o NotoSans-Regular.woff2 NotoSans-Regular.ttf

# Use Nginx base image for serving font
FROM nginx:alpine

# Copy processed font from the font-processor stage
COPY --from=font-processor /fonts/NotoSans-Regular.woff2 /usr/share/nginx/html/fonts/

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]