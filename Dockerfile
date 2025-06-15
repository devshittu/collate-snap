# Use Ubuntu 24.04 as base, matching your system
FROM ubuntu:24.04

# Install basic dependencies for the collate script

# Removing systemd and snapd as they are not needed for simple script execution

# and cause issues with container startup if not managed carefully.

RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create the directory for system-wide config if it doesn't exist
RUN mkdir -p /etc/collate/

# Copy the system-wide config.yaml
COPY config.yaml /etc/collate/config.yaml

# Copy project files into the /app directory in the container

COPY . /app

# Set the working directory to /app

WORKDIR /app

# Make the collate.sh script executable

RUN chmod +x /app/collate.sh
RUN chmod +x /app/test_collate.sh

# Create symlinks to make collate and col8 accessible in the PATH for tests

# This ensures test\_collate.sh can find 'collate' and 'col8' commands.

RUN ln -s /app/collate.sh /usr/local/bin/collate
RUN ln -s /app/collate.sh /usr/local/bin/col8

# Set the default command to an endlessly running but lightweight process

# This keeps the container alive for `docker compose exec` commands without

# requiring systemd or complex init setup.

CMD ["tail", "-f", "/dev/null"]


# Dockerfile