FROM nvidia/cuda:12.9.0-runtime-ubuntu24.04

# Set non-interactive frontend and timezone
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install prerequisites
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-dev \
    python3.12-distutils \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    tzdata \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1

# Install pip
RUN wget https://bootstrap.pypa.io/get-pip.py \
    && python3.12 get-pip.py \
    && rm get-pip.py \
    && python3.12 -m pip install --upgrade pip

# Install core Python dependencies
RUN python3.12 -m pip install --no-cache-dir setuptools wheel

# Set working directory
WORKDIR /app

####################
# Stable Diffusion #
####################

# Set environment variable for Stable Diffusion release version (default to stable commit)
ENV SD_RELEASE_VERSION=""
ENV STABLE_HASH=5ab7f2138c1b816f9b4acb943696d82c8b21d08c

# Clone Stable Diffusion and checkout specified release or fallback to stable commit
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git . \
    && if [ -n "$SD_RELEASE_VERSION" ]; then git checkout "$SD_RELEASE_VERSION"; else git checkout "$STABLE_HASH"; fi

# Pre-install Python dependencies
RUN python3.12 -m pip install --no-cache-dir torch==2.4.1 torchvision==0.19.1 torchaudio==2.4.1 --index-url https://download.pytorch.org/whl/cu129 \
    && python3.12 -m pip install --no-cache-dir xformers==0.0.28 \
    && python3.12 -m pip install --no-cache-dir -r requirements.txt

# Run as non-root user
RUN useradd -m -u 1000 appuser
USER 1000
WORKDIR /app

# Expose port
EXPOSE 7860

# Run web UI
CMD ["python3.12", "launch.py", "--listen", "--port", "7860", "--no-download-sd-model"]
