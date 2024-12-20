# Use nginx as base image
FROM nginx:alpine

# Set environment variables
ARG PORT=80
ENV PORT=$PORT

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy static assets to nginx directory
COPY index.html /usr/share/nginx/html/
COPY styles.css /usr/share/nginx/html/
COPY script.js /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port from environment variable
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]