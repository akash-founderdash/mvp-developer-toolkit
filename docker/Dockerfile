FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=20
ENV PNPM_VERSION=9.3.0

# Create non-root user
RUN groupadd -r mvpuser && useradd -r -g mvpuser -s /bin/bash mvpuser

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install pnpm
RUN npm install -g pnpm@${PNPM_VERSION}

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install gh -y

# Install Vercel CLI
RUN npm install -g vercel@latest

# Install Python dependencies for AWS and GitHub integration
RUN pip3 install \
    boto3 \
    requests \
    PyGithub \
    python-dotenv

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Create application directory
RUN mkdir -p /app && chown mvpuser:mvpuser /app

# Create workspace directory
RUN mkdir -p /workspace && chown mvpuser:mvpuser /workspace

# Copy application scripts
COPY --chown=mvpuser:mvpuser scripts/ /app/scripts/
COPY --chown=mvpuser:mvpuser pipeline.sh /app/

# Make scripts executable
RUN chmod +x /app/pipeline.sh /app/scripts/*.sh

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER mvpuser

# Set default command
CMD ["/app/pipeline.sh"]