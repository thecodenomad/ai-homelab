#!/usr/bin/env bash

# ANSI color codes
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Define file names and upstream URL
BUTANE_FILE="./autorebase.butane"
IGNITION_FILE="./autorebase.ign"
BUTANE_IMAGE="quay.io/coreos/butane:release"
UPSTREAM_URL="https://raw.githubusercontent.com/ublue-os/ucore/main/examples/ucore-autorebase.butane"

# Function to stop the HTTP server container
cleanup() {
  if [ -n "$CONTAINER_ID" ]; then
    echo -e "${YELLOW}Dismounting from Shai-Halud...${NC}"
    $CONTAINER_RUNTIME stop "$CONTAINER_ID" >/dev/null 2>&1
    echo -e "${NC}${GREEN}Only I will remain...${NC}"
  fi
  exit 0
}

# Trap Ctrl+C to clean up the container
trap cleanup SIGINT

# Remove existing autorebase.ign, if present
if [ -f "$IGNITION_FILE" ]; then
  echo -e "${YELLOW}The old Spice vision ($IGNITION_FILE) is swept away by the desert winds...${NC}"
  rm -f "$IGNITION_FILE"
fi

# Check if autorebase.butane exists and prompt for reuse or regeneration
REUSE_BUTANE=false
if [ -f "$BUTANE_FILE" ]; then
  echo -e "${CYAN}The Scroll of Arrakis ($BUTANE_FILE) exists in the sands.${NC}"
  read -p "$(echo -e ${CYAN}Reuse the existing scroll? [y/N]:${NC} ) " REUSE_RESPONSE
  if [[ "$REUSE_RESPONSE" =~ ^[Yy]$ ]]; then
    REUSE_BUTANE=true
  else
    echo -e "${YELLOW}The old Scroll of Arrakis ($BUTANE_FILE) is swept away by the desert winds...${NC}"
    rm -f "$BUTANE_FILE"
  fi
fi

# If not reusing, prompt for image type, tag, credentials, and hostname
if [ "$REUSE_BUTANE" = false ]; then
  # Prompt user to select image type with Dune-themed ASCII art
  echo -e "${YELLOW}=====================================${NC}"
  echo -e "${CYAN}   ~ Shai-Hulud's Path on Arrakis ~${NC}"
  echo -e "${YELLOW}=====================================${NC}"
  echo -e "${CYAN}   ,~^~._"
  echo -e "  / 0 0  \\  Choose your destiny:${NC}"
  echo -e "${CYAN} :  ___  :  #1: fedora-coreos (The Core Path)${NC}"
  echo -e "${CYAN} :  ===  :  #2: ucore-minimal (The Spartan Way)${NC}"
  echo -e "${CYAN} :  ===  :  #3: ucore (The Fremen's Path, default)${NC}"
  echo -e "${CYAN} :  ===  :  #4: ucore-hci (The Sardaukar's Might, for future VMs)${NC}"
  echo -e "${CYAN}  \\ --- /${NC}"
  echo -e "${YELLOW}=====================================${NC}"
  read -p "$(echo -e ${CYAN}Enter 1, 2, 3, 4, or press Enter for ucore:${NC} ) " IMAGE_INPUT

  # Validate image input, default to ucore
  case "$IMAGE_INPUT" in
    1)
      IMAGE_TYPE="fedora-coreos"
      ;;
    2)
      IMAGE_TYPE="ucore-minimal"
      ;;
    3|"")
      IMAGE_TYPE="ucore"
      ;;
    4)
      IMAGE_TYPE="ucore-hci"
      ;;
    *)
      echo -e "${RED}Error: The Sands reject '$IMAGE_INPUT'. Choose '1', '2', '3', '4', or Enter, Fremen!${NC}"
      exit 1
      ;;
  esac

  # Prompt user to select tag type (stable or testing)
  echo -e "${YELLOW}=====================================${NC}"
  echo -e "${CYAN}   ~ Choosing the Spice's Purity ~${NC}"
  echo -e "${YELLOW}=====================================${NC}"
  echo -e "${CYAN} :  ___  :  #1: stable (The Proven Path, default)${NC}"
  echo -e "${CYAN} :  ===  :  #2: testing (The Uncharted Sands)${NC}"
  echo -e "${CYAN}  \\ --- /${NC}"
  echo -e "${YELLOW}=====================================${NC}"
  read -p "$(echo -e ${CYAN}Enter 1, 2, or press Enter for stable:${NC} ) " TAG_TYPE_INPUT

  # Validate tag type input, default to stable
  case "$TAG_TYPE_INPUT" in
    1|"")
      TAG_TYPE="stable"
      ;;
    2)
      TAG_TYPE="testing"
      ;;
    *)
      echo -e "${RED}Error: The Sands reject '$TAG_TYPE_INPUT'. Choose '1', '2', or Enter, Fremen!${NC}"
      exit 1
      ;;
  esac

  # Define tag variants based on image and tag type
  if [ "$IMAGE_TYPE" = "fedora-coreos" ]; then
    TAG_VARIANTS=("${TAG_TYPE}-nvidia" "${TAG_TYPE}-zfs" "${TAG_TYPE}-nvidia-zfs")
    DEFAULT_TAG="${TAG_TYPE}-nvidia"  # Default for fedora-coreos
  else
    TAG_VARIANTS=("$TAG_TYPE" "${TAG_TYPE}-nvidia" "${TAG_TYPE}-zfs" "${TAG_TYPE}-nvidia-zfs")
    DEFAULT_TAG="$TAG_TYPE"  # Default for ucore, ucore-minimal, ucore-hci
  fi

  # Prompt user to select tag variant
  echo -e "${YELLOW}=====================================${NC}"
  echo -e "${CYAN}   ~ Shaping the Spice's Form ~${NC}"
  echo -e "${YELLOW}=====================================${NC}"
  echo -e "${CYAN} :  ___  :  #1: ${TAG_VARIANTS[0]} (default)${NC}"
  echo -e "${CYAN} :  ===  :  #2: ${TAG_VARIANTS[1]}${NC}"
  echo -e "${CYAN} :  ===  :  #3: ${TAG_VARIANTS[2]}${NC}"
  if [ "${#TAG_VARIANTS[@]}" -eq 4 ]; then
    echo -e "${CYAN} :  ===  :  #4: ${TAG_VARIANTS[3]}${NC}"
  fi
  echo -e "${CYAN}  \\ --- /${NC}"
  echo -e "${YELLOW}=====================================${NC}"
  read -p "$(echo -e ${CYAN}Enter 1, 2, 3, ${TAG_VARIANTS[3]:+4, }or press Enter for ${TAG_VARIANTS[0]}:${NC} ) " TAG_VARIANT_INPUT

  # Validate tag variant input, default to base tag
  case "$TAG_VARIANT_INPUT" in
    1|"")
      TAG="${TAG_VARIANTS[0]}"
      ;;
    2)
      TAG="${TAG_VARIANTS[1]}"
      ;;
    3)
      TAG="${TAG_VARIANTS[2]}"
      ;;
    4)
      if [ "${#TAG_VARIANTS[@]}" -eq 4 ]; then
        TAG="${TAG_VARIANTS[3]}"
      else
        echo -e "${RED}Error: The Sands reject '$TAG_VARIANT_INPUT'. Choose '1', '2', '3', or Enter, Fremen!${NC}"
        exit 1
      fi
      ;;
    *)
      echo -e "${RED}Error: The Sands reject '$TAG_VARIANT_INPUT'. Choose '1', '2', '3', ${TAG_VARIANTS[3]:+4, }or Enter, Fremen!${NC}"
      exit 1
      ;;
  esac

  # Construct the image URL
  IMAGE_URL="ghcr.io/ublue-os/$IMAGE_TYPE:$TAG"

  # Fetch the latest autorebase.butane
  echo -e "${CYAN}Summoning the ancient scroll from the upstream sands...${NC}"
  if ! curl -s -f -L "$UPSTREAM_URL" -o "$BUTANE_FILE"; then
    echo -e "${RED}Error: Failed to retrieve the Scroll of Arrakis from $UPSTREAM_URL. Check your connection, Fremen!${NC}"
    exit 1
  fi

  # Verify the Butane file was created
  if [ ! -f "$BUTANE_FILE" ]; then
    echo -e "${RED}Error: The Scroll of Arrakis ('$BUTANE_FILE') could not be forged.${NC}"
    exit 1
  fi

  # Prompt for SSH key, password, and hostname
  echo -e "${YELLOW}=====================================${NC}"
  echo -e "${CYAN}   ~ Forging the Sietch's Secrets ~${NC}"
  echo -e "${YELLOW}=====================================${NC}"
  echo -e "${CYAN}Fremen, present your Sietch key (SSH public key, e.g., ssh-rsa AAA...):${NC}"
  read -r SSH_PUB_KEY
  if [ -z "$SSH_PUB_KEY" ]; then
    echo -e "${RED}Error: The Sietch key cannot be empty, Fremen!${NC}"
    exit 1
  fi

  echo -e "${CYAN}Speak the Water of Life (password for 'core' user):${NC}"
  read -s PASSWORD
  echo
  if [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: The Water of Life cannot be empty, Fremen!${NC}"
    exit 1
  fi

  echo -e "${CYAN}Confirm the Water of Life (re-enter password):${NC}"
  read -s PASSWORD_CONFIRM
  echo
  if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Error: The Waters of Life do not align! Passwords must match, Fremen!${NC}"
    exit 1
  fi

  echo -e "${CYAN}Name your Sietch (hostname for the machine, e.g., my-machine):${NC}"
  read -r HOSTNAME
  if [ -z "$HOSTNAME" ]; then
    echo -e "${RED}Error: The Sietch name cannot be empty, Fremen!${NC}"
    exit 1
  fi
  # Basic hostname validation (alphanumeric, hyphens, no spaces)
  if ! echo "$HOSTNAME" | grep -q '^[a-zA-Z0-9][a-zA-Z0-9-]*$'; then
    echo -e "${RED}Error: The Sietch name '$HOSTNAME' is invalid. Use alphanumeric characters and hyphens, Fremen!${NC}"
    exit 1
  fi

  # Generate password hash
  if ! PASSWORD_HASH=$(openssl passwd -6 "$PASSWORD"); then
    echo -e "${RED}Error: The Spice could not forge the password hash.${NC}"
    exit 1
  fi

  # Modify the Butane file with user-provided values
  sed -i "s|YOUR_SSH_PUB_KEY_HERE|$SSH_PUB_KEY|" "$BUTANE_FILE"
  sed -i "s|YOUR_GOOD_PASSWORD_HASH_HERE|$PASSWORD_HASH|" "$BUTANE_FILE"

  # Check if storage section exists, and append or create files entry
  if grep -q '^storage:' "$BUTANE_FILE"; then
    # Storage section exists, append files entry
    sed -i '/^storage:/a\  files:\n    - path: /etc/hostname\n      mode: 0644\n      contents:\n        inline: '"$HOSTNAME" "$BUTANE_FILE"
  else
    # No storage section, create one with files entry
    cat >> "$BUTANE_FILE" << EOF
storage:
  files:
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: $HOSTNAME
EOF
  fi

  # Update the image URL in the Butane file, matching the full URL with tag
  sed -i "s|ghcr.io/ublue-os/ucore:[^ ]*|$IMAGE_URL|g" "$BUTANE_FILE"
  sed -i "s|ghcr.io/ublue-os/ucore-hci:[^ ]*|$IMAGE_URL|g" "$BUTANE_FILE"
fi

# Check for podman or docker
CONTAINER_RUNTIME=""
VOLUME_MOUNT="$(pwd):/workdir"
if command -v podman >/dev/null 2>&1; then
  CONTAINER_RUNTIME="podman"
  VOLUME_MOUNT="$(pwd):/workdir:Z"  # Add :Z for SELinux compatibility
  echo -e "${CYAN}Summoning Shai-Hulud with podman as the Sandrider.${NC}"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_RUNTIME="docker"
  echo -e "${CYAN}Summoning Shai-Hulud with docker as the Sandrider.${NC}"
else
  echo -e "${RED}Error: No Sandrider (podman or docker) is present. Summon one to proceed!${NC}"
  exit 1
fi

# Run butane to convert the Butane file to Ignition
echo -e "${CYAN}Weaving the Spice into $IGNITION_FILE using butane...${NC}"
if ! $CONTAINER_RUNTIME run --rm -v "$VOLUME_MOUNT" -w /workdir "$BUTANE_IMAGE" \
  --pretty --strict "$BUTANE_FILE" > "$IGNITION_FILE"; then
  echo -e "${RED}Error: The Spice weave failed for $BUTANE_FILE to $IGNITION_FILE.${NC}"
  exit 1
fi

# Verify the Ignition file was created
if [ ! -f "$IGNITION_FILE" ]; then
  echo -e "${RED}Error: The Spice vision '$IGNITION_FILE' did not manifest.${NC}"
  exit 1
fi

echo -e "${GREEN}Success: The Spice vision '$IGNITION_FILE' has been forged!${NC}"

# Prompt user to share the Ignition file
echo -e "${YELLOW}=====================================${NC}"
echo -e "${CYAN}   ~ Sharing the Spice Vision ~${NC}"
echo -e "${YELLOW}=====================================${NC}"
read -p "$(echo -e ${CYAN}Share the Spice vision \($IGNITION_FILE\) over the sands \(HTTP\)? [y/N]:${NC} ) " SHARE_RESPONSE
if [[ ! "$SHARE_RESPONSE" =~ ^[Yy]$ ]]; then
  echo -e "${CYAN}The Spice vision remains in your Sietch. Farewell, Fremen!${NC}"
  exit 0
fi

# Determine host IP address
HOST_IP=$(hostname -I | awk '{print $1}' || ip addr show | grep -oP 'inet \K[\d.]+' | head -n 1)
if [ -z "$HOST_IP" ]; then
  echo -e "${RED}Error: Could not set the thumper (host IP address). Cannot share the Spice vision!${NC}"
  exit 1
fi

# Start HTTP server container and capture container ID
echo -e "${CYAN}Thumper is set and summoning Shai-Hulud. Check your stillsuit and prepare your hooks...${NC}"
CONTAINER_ID=$($CONTAINER_RUNTIME run -d --rm -v "$VOLUME_MOUNT" -w /workdir -p 8000:8000 python:3-slim \
  python -m http.server 8000)
if [ $? -ne 0 ]; then
  echo -e "${RED}Error: Failed to raise the beacon (HTTP server). The Spice vision cannot be shared!${NC}"
  exit 1
fi

# Display ASCII art with beacon information on the right and CoreOS command below
echo -e ""
echo -e "${CYAN}               ,odoxOOO0K0xdxxkxoc,.              ${NC}${GREEN}The worm is summoned!${NC}"
echo -e "${CYAN}            'lOOOkkOOOO0O0OOxOkk0OOX0;            ${NC}${GREEN}http://$HOST_IP:8000/$IGNITION_FILE${NC}"
echo -e "${CYAN}           lx:ldcKko;'...;'.':odOxkkOKx           ${NC}"
echo -e "${CYAN}          :;cx0O;' ..'...cc.'....,odxkKO:         ${NC}"
echo -e "${CYAN}         ::dKxo...,'',cc'ccc:;,c''..'oxkx;        ${NC}"
echo -e "${CYAN}        olKXO..,;:;:c:;:;lc::cl:cc;,..,ko,        ${NC}"
echo -e "${CYAN}       .cOKk. ':olclc:c':;:,lc:lc:::;',,k',       ${NC}"
echo -e "${CYAN}       'kXXo..'.,:clcc',...'';;:lllc:;'.:x'       ${NC}"
echo -e "${CYAN}       l0kk;.'::;::cl:,.    .'::::;:ccc;.Ox,      ${NC}"
echo -e "${CYAN}       0Xoo,..,:clc::c;.     .',::::;:l..X0.      ${NC}"
echo -e "${CYAN}      .lXxO;..',::::l:;,.....,:;;cc::c:'.Kc       ${NC}"
echo -e "${CYAN}      ,xkkKx..;:;:ccc:x;cl;:;,:c;,;cc,,';0.       ${NC}"
echo -e "${CYAN}    ''.'cOKO:..';:cllklodlldo:,c:,'.','c0c.;      ${NC}"
echo -e "${CYAN}   .,..:;.,ox;...;;colo:oo.ooo;':,....xd,.',,     ${NC}"
echo -e "${CYAN}    ,looOo,.c0O,..;'::lc;c';:cl'.. ,oxc:xc:ck.    ${NC}"
echo -e "${CYAN}     .WNkl:'..okxc,;..''',..'....lx0d;x00Wdo      ${NC}"
echo -e "${CYAN}       ,  :l;,.',:ookdoo;,c:cddxlccoxKXMKd        ${NC}"
echo -e "${CYAN}                .;'',:loododl,.:cdOO.xk:          ${NC}"
echo -e "${CYAN}                    ..    :c       .              ${NC}"
echo -e ""
echo -e "${CYAN}On your CoreOS machine, summon the vision with this command:${NC}"
echo -e "${YELLOW}coreos-installer install /dev/sda --insecure-ignition --ignition-url http://$HOST_IP:8000/$IGNITION_FILE${NC}"
echo -e ""
echo -e "${CYAN}Press Ctrl+C to dismount from Shai-Halud.${NC}"
echo -e ""

# Keep the script running to maintain the container
sleep infinity
