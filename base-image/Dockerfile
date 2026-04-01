FROM ubuntu:24.04   

ENV DEBIAN_FRONTEND=noninteractive   

ENV HELM_VERSION=v3.12.0   
ENV YQ_VERSION=v4.40.5    

# Install required packages
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    bash \
    gnupg \
    lsb-release \
    apt-transport-https \
    unzip \
    jq && \
    rm -rf /var/lib/apt/lists/*

# Install Helm
RUN curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o /tmp/helm.tgz && \
    tar -zxvf /tmp/helm.tgz -C /tmp && \
    mv /tmp/linux-amd64/helm /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm && \
    rm -rf /tmp/helm.tgz /tmp/linux-amd64

# Install yq
RUN curl -L https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Default command
CMD ["bash", "-c", "helm version || true; yq --version || true; git --version || true"]