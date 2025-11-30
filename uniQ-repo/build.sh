```bash name=build.sh
#!/usr/bin/env bash
set -euo pipefail

# Build script to build all unikernels for chosen backend.
# Usage:
#  ./build.sh xen    # builds all unikernels for Xen
#  ./build.sh solo5  # builds all unikernels for Solo5/HVT
#  ./build.sh xen cryptod   # build only cryptod for xen

BACKEND=${1:-xen}
UNIKERNEL_ARG=${2:-all}

UNIKERNELS=(cryptod entropyd unlocker policy_pd netfw_pd ivm_pd)

build_one() {
  local u="$1"
  echo "Building $u for backend $BACKEND"
  export UNIKERNEL="$u"
  mirage configure -t "$BACKEND"
  make
  # move artifact to images/ directory
  mkdir -p images/"$BACKEND"
  if [ "$BACKEND" = "xen" ]; then
    # Xen unikernel image artifact name differs by toolchain; attempt common names
    mv _build/"$u".xl images/"$BACKEND"/"$u".xl 2>/dev/null || true
    mv _build/"$u".xen images/"$BACKEND"/"$u".xen 2>/dev/null || true
    # fallback: move any generated file with the unikernel name
    find _build -maxdepth 1 -type f -name "*$u*" -exec mv {} images/"$BACKEND"/ \; 2>/dev/null || true
  else
    # Solo5 artifacts (hvt) are often in _build/hvt
    mv _build/*/"$u" images/"$BACKEND"/ 2>/dev/null || true
  fi
  echo "Built $u -> images/$BACKEND/"
}

if [ "$UNIKERNEL_ARG" = "all" ]; then
  for u in "${UNIKERNELS[@]}"; do
    build_one "$u"
  done
else
  build_one "$UNIKERNEL_ARG"
fi

echo "Build complete."
```
