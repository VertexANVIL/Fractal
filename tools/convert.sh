#!/usr/bin/env bash
for i in *.yaml; do
    strip=${i%.*}
    [ -f "$i" ] || break
    yq e -j "$i" | python3 ./json2nix.py /dev/stdin > "$strip.nix"
done
