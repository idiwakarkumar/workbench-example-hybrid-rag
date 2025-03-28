#!/bin/bash
set -e

# Fix SSL issues more thoroughly
mkdir -p $HOME/.conda
cat > $HOME/.conda/condarc << EOF
ssl_verify: false
channels:
  - defaults
channel_priority: flexible
EOF

# Set the SSL verification to false for conda and pip
conda config --set ssl_verify false

# Update certificates first with more robust error handling
sudo -E apt-get update || echo "apt-get update failed, continuing anyway"
sudo -E apt-get -y install --reinstall ca-certificates openssl || echo "ca-certificates reinstall failed, continuing anyway"

# Fix potential SSL/TLS issues in Python
export PYTHONHTTPSVERIFY=0
export REQUESTS_CA_BUNDLE=""

# Install deps to run the API in a separate venv with improved pip options
conda create --name api-env -y python=3.10 pip
$HOME/.conda/envs/api-env/bin/pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host conda.anaconda.org --no-cache-dir fastapi==0.109.2 uvicorn[standard]==0.27.0.post1 python-multipart==0.0.7 langchain==0.0.335 langchain-community==0.0.19 openai==1.55.3 httpx==0.27.2 unstructured[all-docs]==0.12.4 sentence-transformers==2.7.0 llama-index==0.9.44 dataclass-wizard==0.22.3 pymilvus==2.3.1 opencv-python==4.8.0.76 hf_transfer==0.1.5 text_generation==0.6.1 transformers==4.40.0 nltk==3.8.1

# Install deps to run the UI in a separate venv with improved pip options
conda create --name ui-env -y python=3.10 pip
$HOME/.conda/envs/ui-env/bin/pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host conda.anaconda.org --no-cache-dir dataclass_wizard==0.22.2 gradio==4.15.0 jinja2==3.1.2 numpy==1.25.2 protobuf==3.20.3 PyYAML==6.0 uvicorn==0.22.0 torch==2.1.1 tiktoken==0.7.0 regex==2024.5.15 fastapi==0.112.2

# Install Docker CLI
sudo -E apt-get update || echo "apt-get update failed, continuing anyway"
sudo -E apt-get -y install ca-certificates curl || echo "ca-certificates/curl install failed, continuing anyway"
sudo -E install -m 0755 -d /etc/apt/keyrings
sudo -E curl -fsSL --insecure https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo -E chmod a+r /etc/apt/keyrings/docker.asc

# Properly format the echo command to avoid Windows line ending issues
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo -E tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo -E apt-get update || echo "apt-get update failed, continuing anyway"
sudo -E apt-get -y install docker-ce-cli || echo "docker-ce-cli install failed, continuing anyway"

# Install additional pip packages with improved options
sudo -E /opt/conda/bin/pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host conda.anaconda.org --no-cache-dir anyio==4.3.0 pymilvus==2.3.1 transformers==4.40.0

# Create necessary directories
sudo -E mkdir -p /mnt/milvus
sudo -E mkdir -p /data
sudo -E chown workbench /mnt/milvus
sudo -E chown workbench /data

# Install git-lfs
sudo -E curl -s --insecure https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo -E bash
sudo -E apt-get install git-lfs || echo "git-lfs install failed, continuing anyway"

# Fix here-document for Docker access (proper EOF delimiter)
sudo tee /etc/profile.d/docker-in-docker.sh > /dev/null << 'EOF'
if ! groups workbench | grep docker > /dev/null; then
    docker_gid=$(stat -c %g /var/host-run/docker.sock)
    sudo groupadd -g $docker_gid docker
    sudo usermod -aG docker workbench
fi
EOF

# Grant user sudo access
echo "workbench ALL=(ALL) NOPASSWD:ALL" | \
    sudo tee /etc/sudoers.d/00-workbench > /dev/null