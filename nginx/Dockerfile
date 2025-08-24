FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Remove default nginx configuration (if it exists)
RUN rm -f /etc/nginx/conf.d/default.conf.bak

# Set proper permissions for nginx directories
RUN chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx/conf.d

# Create pid directory with proper permissions
RUN mkdir -p /var/run && chown -R nginx:nginx /var/run

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]