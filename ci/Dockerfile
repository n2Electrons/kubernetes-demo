# Multi-stage Dockerfile for NGINX demo application
# This Dockerfile creates a lightweight NGINX container with custom content

FROM nginx:alpine as builder

# Add build metadata
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Copy custom NGINX configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy application content
COPY html/ /usr/share/nginx/html/

# Add custom index page with build info
RUN echo "<!DOCTYPE html>" > /usr/share/nginx/html/index.html && \
    echo "<html><head><title>Kub-App Demo</title></head><body>" >> /usr/share/nginx/html/index.html && \
    echo "<h1>Kubernetes Demo Application</h1>" >> /usr/share/nginx/html/index.html && \
    echo "<p>Build Date: ${BUILD_DATE}</p>" >> /usr/share/nginx/html/index.html && \
    echo "<p>Version: ${VERSION}</p>" >> /usr/share/nginx/html/index.html && \
    echo "<p>Git Commit: ${VCS_REF}</p>" >> /usr/share/nginx/html/index.html && \
    echo "<p>This application is running in a Kubernetes cluster with GitOps deployment.</p>" >> /usr/share/nginx/html/index.html && \
    echo "</body></html>" >> /usr/share/nginx/html/index.html

# Production stage
FROM nginx:alpine

# Install curl for health checks
RUN apk --no-cache add curl

# Copy configuration and content from builder
COPY --from=builder /etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /usr/share/nginx/html/ /usr/share/nginx/html/

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Add labels for metadata
LABEL org.opencontainers.image.title="Kub-App Demo" \
      org.opencontainers.image.description="NGINX demo application for Kubernetes GitOps" \
      org.opencontainers.image.source="https://github.com/n2Electrons/kubernetes-demo" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

# Use non-root user for security
RUN addgroup -g 1001 -S nginx && \
    adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx /usr/share/nginx/html

USER nginx

# Expose port
EXPOSE 8080

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]