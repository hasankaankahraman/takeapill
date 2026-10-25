#!/bin/sh
# store_assets_test.dart'ın ürettiği PNG'leri mağazaların istediği alfa
# kanalsız JPEG'lere çevirir ve Google Play için 512 px ikonu hazırlar.
set -e
cd "$(dirname "$0")/../.."

find store -name '*.png' ! -name 'icon-512.png' | while read -r png; do
  sips -s format jpeg -s formatOptions 92 "$png" --out "${png%.png}.jpg" >/dev/null
  rm "$png"
done
sips -z 512 512 assets/icon/icon.png --out store/google-play/icon-512.png >/dev/null

find store -type f \( -name '*.jpg' -o -name '*.png' \) | sort | while read -r f; do
  printf '%s  %sx%s\n' "$f" \
    "$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')" \
    "$(sips -g pixelHeight "$f" | awk '/pixelHeight/ {print $2}')"
done
