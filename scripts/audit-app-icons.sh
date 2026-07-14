#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PALETTE="$ROOT/Resources/AppIconSources/AppIconPalette.json"
CATALOG="$ROOT/Ohana/Assets.xcassets"
ICON_COMPOSER_ROOT="$ROOT/Ohana/AppIcons"
MARK_SOURCE="$ROOT/Resources/AppIconSources/OhanaMark.svg"

fail() {
    echo "App icon audit: $*" >&2
    exit 1
}

command -v jq >/dev/null || fail "jq is required"
command -v sips >/dev/null || fail "sips is required"
jq empty "$PALETTE" || fail "invalid palette JSON"
[[ -f "$MARK_SOURCE" ]] || fail "missing Icon Composer mark source"

while IFS= read -r asset_set; do
    icon_package="$ICON_COMPOSER_ROOT/$asset_set.icon"
    icon_document="$icon_package/icon.json"
    icon_mark="$icon_package/Assets/OhanaMark.svg"
    [[ -f "$icon_document" ]] || fail "missing $asset_set.icon/icon.json"
    [[ -f "$icon_mark" ]] || fail "missing $asset_set.icon/Assets/OhanaMark.svg"
    jq empty "$icon_document" || fail "invalid $asset_set.icon/icon.json"
    [[ "$(jq -r '.groups[0].layers[0]["image-name"]' "$icon_document")" == "OhanaMark.svg" ]] || \
        fail "$asset_set.icon must reference OhanaMark.svg"
    [[ "$(jq '.groups[0].layers[0]["fill-specializations"] | length' "$icon_document")" == "3" ]] || \
        fail "$asset_set.icon must define default, dark, and tinted mark fills"
    [[ "$(jq '[.groups[0].layers[0]["fill-specializations"][] | .appearance // "default"] | sort | join(",")' -r "$icon_document")" == "dark,default,tinted" ]] || \
        fail "$asset_set.icon mark appearances must be default, dark, and tinted"
    [[ "$(jq '[.["fill-specializations"][] | .appearance // "default"] | sort | join(",")' -r "$icon_document")" == "dark,default" ]] || \
        fail "$asset_set.icon background appearances must be default and dark"
    [[ "$(shasum -a 256 "$icon_mark" | awk '{print $1}')" == "$(shasum -a 256 "$MARK_SOURCE" | awk '{print $1}')" ]] || \
        fail "$asset_set.icon mark must match the canonical OhanaMark.svg"

    set_dir="$CATALOG/$asset_set.appiconset"
    contents="$set_dir/Contents.json"
    [[ -f "$contents" ]] || fail "missing $asset_set.appiconset"

    filenames=()
    while IFS= read -r filename; do
        filenames+=("$filename")
    done < <(jq -r '.images[] | .filename // empty' "$contents" | sort -u)
    [[ ${#filenames[@]} -eq 3 ]] || fail "$asset_set must use three distinct appearance files"

    hashes=()
    for filename in "${filenames[@]}"; do
        file="$set_dir/$filename"
        [[ -f "$file" ]] || fail "missing $file"
        width="$(sips -g pixelWidth "$file" 2>/dev/null | awk '/pixelWidth/{print $2}')"
        height="$(sips -g pixelHeight "$file" 2>/dev/null | awk '/pixelHeight/{print $2}')"
        alpha="$(sips -g hasAlpha "$file" 2>/dev/null | awk '/hasAlpha/{print $2}')"
        [[ "$width" == "1024" && "$height" == "1024" ]] || fail "$file must be 1024 x 1024"
        [[ "$alpha" == "no" ]] || fail "$file must not contain an alpha channel"
        hashes+=("$(shasum -a 256 "$file" | awk '{print $1}')")
    done

    unique_hashes="$(printf '%s\n' "${hashes[@]}" | sort -u | wc -l | tr -d ' ')"
    [[ "$unique_hashes" == "3" ]] || fail "$asset_set appearances must be visually distinct files"

    preview_dir="$CATALOG/${asset_set}Preview.imageset"
    preview_contents="$preview_dir/Contents.json"
    [[ -f "$preview_contents" ]] || fail "missing ${asset_set}Preview.imageset"

    preview_filenames=()
    while IFS= read -r filename; do
        preview_filenames+=("$filename")
    done < <(jq -r '.images[] | .filename // empty' "$preview_contents" | sort -u)
    [[ ${#preview_filenames[@]} -eq 2 ]] || fail "${asset_set}Preview must use distinct default and dark files"

    preview_hashes=()
    for filename in "${preview_filenames[@]}"; do
        file="$preview_dir/$filename"
        [[ -f "$file" ]] || fail "missing $file"
        width="$(sips -g pixelWidth "$file" 2>/dev/null | awk '/pixelWidth/{print $2}')"
        height="$(sips -g pixelHeight "$file" 2>/dev/null | awk '/pixelHeight/{print $2}')"
        alpha="$(sips -g hasAlpha "$file" 2>/dev/null | awk '/hasAlpha/{print $2}')"
        [[ "$width" == "1024" && "$height" == "1024" ]] || fail "$file must be 1024 x 1024"
        [[ "$alpha" == "no" ]] || fail "$file must not contain an alpha channel"
        preview_hashes+=("$(shasum -a 256 "$file" | awk '{print $1}')")
    done

    preview_unique_hashes="$(printf '%s\n' "${preview_hashes[@]}" | sort -u | wc -l | tr -d ' ')"
    [[ "$preview_unique_hashes" == "2" ]] || fail "${asset_set}Preview default and dark files must differ"
done < <(jq -r '.variants[].assetSet' "$PALETTE")

for plist in "$ROOT/Ohana/Info.plist" "$ROOT/Ohana/InfoLocalDevice.plist"; do
    if plutil -extract CFBundleIcons xml1 -o - "$plist" >/dev/null 2>&1; then
        fail "$(basename "$plist") manually declares CFBundleIcons; use Xcode build settings"
    fi
done

echo "App icon audit: passed"
