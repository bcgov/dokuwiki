# Start from the official DokuWiki image.
# Using 'latest' or a specific version like '2024-02-06a' is recommended for stability.
FROM dokuwiki/dokuwiki:latest

# Define build argument for the SMTP plugin version.
# Check https://github.com/splitbrain/dokuwiki-plugin-smtp/releases for the latest stable version.
ARG SMTP_PLUGIN_VERSION="2023-01-20"
ARG SMTP_PLUGIN_PATH="https://github.com/splitbrain/dokuwiki-plugin-smtp/zipball/master"

# Switch to root user to install system packages and modify configurations.
USER root

# Install necessary dependencies for downloading and extracting the plugin.
# --no-install-recommends reduces image size by avoiding recommended but not strictly necessary packages.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    unzip && \
    rm -rf /var/lib/apt/lists/* # Clean up apt cache to keep image small

# --- Apache Port Configuration ---
# Replace ports.conf entirely to ensure Apache listens on port 8080
RUN echo "Listen 8080" > /etc/apache2/ports.conf && \
    sed -i 's/<VirtualHost *:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf


# --- Healthcheck File ---
# Based on your previous Dockerfile and Helm probe configurations,
# it's assumed you have a `health.php` file for readiness/liveness checks.
# This command copies your local `root/var/www/html/health.php` into the image.
# Ensure this file exists in your Docker build context.
COPY root/var/www/html/health.php /var/www/html/health.php

# --- DokuWiki SMTP Plugin Installation ---
# Set the working directory to a temporary location for downloading the plugin.
WORKDIR /tmp

# --- DokuWiki SMTP Plugin Installation ---
# Set the working directory to a temporary location for downloading and processing.
# We create a unique temporary directory to avoid conflicts if /tmp contains other files.
WORKDIR /tmp/dokuwiki_plugin_install

# Download the SMTP plugin from the specified URL, unzip it,
# and move the extracted directory to the DokuWiki plugins directory.
# The plugin will be installed in /dokuwiki/lib/plugins/smtp.
RUN set -eux; \
    mkdir -p /tmp/dokuwiki_plugin_install; \
    cd /tmp/dokuwiki_plugin_install; \
    curl -fL -o smtp.zip ${SMTP_PLUGIN_PATH}; \
    unzip smtp.zip; \
    mkdir -p /dokuwiki/lib/plugins/smtp; \
    # Move all contents from the extracted folder(s) into the smtp plugin directory
    cp -r ./splitbrain-dokuwiki-plugin-smtp* /dokuwiki/lib/plugins/smtp; \
    rm smtp.zip; \
    rm -rf /tmp/dokuwiki_plugin_install;

# --- Permissions for added files and directories ---
# The official `dokuwiki/dokuwiki` image primarily uses the `www-data` user (UID/GID 33).
# We must ensure that the `health.php` and the newly installed `smtp` plugin directory
# are owned by this user so DokuWiki can access and execute them.
RUN chown www-data:www-data /var/www/html/health.php && \
    chmod +x /var/www/html/health.php && \
    chown -R www-data:www-data /dokuwiki/lib/plugins/smtp

# Expose the custom port that Apache is now configured to listen on.
# This matches the `targetPort` in your Helm service definition.
EXPOSE 8080

# Switch to the non-root user `www-data`.
# The base image's Dockerfile usually sets this, but it's good practice to be explicit
# to ensure all subsequent commands (if any) and the container's runtime
# operate under this non-privileged user.
USER www-data

# The official dokuwiki/dokuwiki image provides its own ENTRYPOINT.
# We do not need to define one here unless you require custom startup logic
# that is not handled by the official image's entrypoint.