FROM nvidia/cuda:12.8.1-base-ubuntu22.04 as base

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

FROM base as base-user

#######################
# Setup Non-Root User #
#######################

# Create working directory and home directory for UID 1000
RUN mkdir -p /app /home/1000 /output_data /opt/venv /opt/models \
    && chown 1000:1000 /app /home/1000 /output_data /opt/venv /opt/models

# Set home directory for UID 1000
ENV HOME=/home/1000

# Switch to non-root user (UID 1000)
USER 1000

FROM base-user as dependency-base

############################################
# Setup Rust Dependencies for Transformers #
############################################

# Install rustup and Rust toolchain, sourcing env to update PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable 

ENV PATH="/home/1000/.cargo/bin:${PATH}"
RUN rustup update stable

# Set working directory
WORKDIR /app

####################################
# Setup Common Python Dependencies #
####################################

# Create virtual environment
RUN python3.10 -m venv /opt/venv

# Install pip, setuptools, wheel in virtual environment
RUN /opt/venv/bin/pip install --upgrade pip setuptools wheel

# Install Python dependencies with Python 3.10
RUN /opt/venv/bin/pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
RUN /opt/venv/bin/pip install --no-cache-dir xformers

FROM dependency-base as sd-webui-base

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

# Bugfix - ref https://github.com/huggingface/transformers/issues/29576
RUN sed -i 's/transformers==4.30.2/transformers==4.51.3/' requirements.txt

# Install application requirements
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM sd-webui-base as sd-webui

EXPOSE 7860

# Run web UI using virtual environment's Python
CMD ["/opt/venv/bin/python3.10", "launch.py", "--listen", "0.0.0.0", "--port", "7860"]

FROM dependency-base as comfyui-base 

#################
# Setup ComfyUI #
#################

# Set ComfyUI release version (default to v0.3.34 commit hash)
ARG COMFY_HASH=158419f3a0017c2ce123484b14b6c527716d6ec8
ENV COMFY_HASH=$COMFY_HASH

# Clone ComfyUI and checkout specified release or fallback to stable commit
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . \
    && if [ -n "$COMFY_HASH" ]; then git checkout "$COMFY_HASH"; else git checkout "$COMFY_HASH"; fi

# Install application requirements
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

COPY ./extra_model_paths.yaml ./

FROM comfyui-base as comfyui

EXPOSE 7861

# Run web UI using virtual environment's Python
CMD ["/opt/venv/bin/python3.10", "main.py", "--listen", "0.0.0.0", "--port", "7861"]

FROM dependency-base as ace-base

#############
# Setup ACE #
#############

ARG ACE_VERSION=330cc0eeb412430d9c551485ec726a5891bf1aef
ENV ACE_VERSION=$ACE_VERSION

# Clone ACE and checkout specified release or fallback to stable commit
RUN git clone https://github.com/ace-step/ACE-Step.git . \
    && git checkout "$ACE_VERSION"

RUN /opt/venv/bin/pip install -r ./requirements.txt
RUN /opt/venv/bin/python ./setup.py install 
RUN mkdir -p /app/outputs /app/checkpoints /app/logs

FROM ace-base as ace 

EXPOSE 7862 

CMD ["/opt/venv/bin/acestep", "--server_name", "0.0.0.0", "--port", "7862"]

