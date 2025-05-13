FROM nvidia/cuda:12.8.1-base-ubuntu22.04

# Set non-interactive frontend and timezone
ENV DEBIAN_FRONTEND=noninteractive

ARG TZ=UTC
ENV TZ=$TZ

########################
# Dependencies Install #
########################

RUN apt-get update && apt-get install -y \
    python3 \
    python3-dev \
    python3-venv \
    gcc \
    g++ \
    git \
    libgl1 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libssl-dev \
    pkg-config \
    sed \
    tzdata \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

#######################
# Setup Non-Root User #
#######################

# Create working directory and home directory for UID 1000
RUN mkdir -p /app /home/1000 \
    && chown 1000:1000 /app /home/1000

# Set home directory for UID 1000
ENV HOME=/home/1000

# Switch to non-root user (UID 1000)
USER 1000

############################################
# Setup Rust Dependencies for Transformers #
############################################

# Install rustup and Rust toolchain, sourcing env to update PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable 

ENV PATH="/home/1000/.cargo/bin:${PATH}"
RUN rustup update stable

# Set working directory
WORKDIR /app

########################################
# Setup Automatic1111 Stable Diffusion #
########################################

# Build Argument to override the version of Stable Diffusion
ARG SD_RELEASE_VERSION=""
ENV SD_RELEASE_VERSION=$SD_RELEASE_VERSION

# Set Stable Diffusion release version (default to v1.10.1 commit hash)
ARG STABLE_HASH=82a973c04367123ae98bd9abdf80d9eda9b910e2
ENV STABLE_HASH=$STABLE_HASH

# Clone Stable Diffusion and checkout specified release or fallback to stable commit
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git . \
    && if [ -n "$SD_RELEASE_VERSION" ]; then git checkout "$SD_RELEASE_VERSION"; else git checkout "$STABLE_HASH"; fi

# Create virtual environment
RUN python3.10 -m venv /app/venv

# Install pip, setuptools, wheel in virtual environment
RUN /app/venv/bin/pip install --upgrade pip setuptools wheel

# Bugfix - ref https://github.com/huggingface/transformers/issues/29576
RUN sed -i 's/transformers==4.30.2/transformers==4.51.3/' requirements.txt

# Install Python dependencies with Python 3.10
RUN /app/venv/bin/pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 
RUN /app/venv/bin/pip install --no-cache-dir xformers
RUN /app/venv/bin/pip install --no-cache-dir -r requirements.txt

# Expose port
EXPOSE 7860

ENV COMMANDLINE_ARGS="--medvram --opt-sdp-attention --xformers --disable-nan-check --api"

# Run web UI using virtual environment's Python
CMD ["/app/venv/bin/python3.10", "launch.py", "--listen", "--port", "7860"]

