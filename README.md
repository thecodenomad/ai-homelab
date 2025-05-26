# ai-homelab
This is a collection of scripts used to aid in the setup of an AI machine in my homelab using [uCore](https://github.com/ublue-os/ucore).

NOTE: The main branch will follow the latest in the AI Series on Medium.

## The Change of Fief

Grab an ISO from the [Fedora CoreOS site](https://fedoraproject.org/coreos/) and throw it on a spare USB drive, and do the sandwalk of getting your homelab system booted.

NOTE: At the time of this writing, Fedora 42 was held back by the uCore team due to the usage of a rawhide kernel. [See the announcement here](https://github.com/ublue-os/ucore?tab=readme-ov-file#announcements)

### Part 1

Since we are focused on getting uCore going grab a copy of the example [ucore-autorebase.butane](https://github.com/ublue-os/ucore/blob/main/examples/ucore-autorebase.butane) and then decide on the [image](https://github.com/ublue-os/ucore?tab=readme-ov-file#features) you'd like to use.

Make the modifications to your butane file, and then compile into an ignition file.

```
podman run --interactive --rm quay.io/coreos/butane:release \
       --pretty --strict < ucore-autorebase.butane > ucore-autorebase.ign
```

Once that's done, you can host your ignition file so that your CoreOS booted machine can reference it:

```
podman run -d --rm -v "$(pwd):/workdir:Z" -w /workdir -p 8000:8000 python:3-slim python -m http.server 8000
```

For more information please reference the [post for this section](https://medium.com/@codenomad/my-dune-inspired-ai-art-homelab-part-1-bad4efff07a7).

#### Automated Script for uCore Setup

The `create_ignition.sh` script is provided to help aid in setting up the ignition script
as well as serving it. Boot your homelab server into CoreOS, and then run this script on a separate computer. The script will walk you through the basic butane configuration and give your the command to execute on your homelab system to install uCoreOS.

(Most *nix systems with docker or podman should support this script)

```
=====================================
   ~ Shai-Hulud's Path on Arrakis ~
=====================================
   ,~^~._
  / 0 0  \  Choose your destiny:
 :  ___  :  #1: fedora-coreos (The Core Path)
 :  ===  :  #2: ucore-minimal (The Spartan Way)
 :  ===  :  #3: ucore (The Fremen's Path, default)
 :  ===  :  #4: ucore-hci (The Sardaukar's Might, for future VMs)
  \ --- /
```

### Part 2

Part 2 repo structure:

├── Containerfile
├── examples
│   ├── example-autorebase.butane
│   └── readme.md
├── models
├── outputs
└── scripts
    └── create_ignition.sh

The updated folder structure will help facilitate the bind mounting into the service(s) in Part 3

NOTE: Going forward all new example files used in posts will be placed in the ./examples/ folder and all helper scripts will be placed in the ./scripts/ folder.
