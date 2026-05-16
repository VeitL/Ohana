#!/bin/sh
set -eu

echo "Repository size:"
du -sh . .git .git/objects

echo
echo "Tracked tmp files:"
git ls-files tmp | wc -l | tr -d ' '
echo

echo
echo "Reachable history objects under tmp/:"
git rev-list --objects --all -- tmp | wc -l | tr -d ' '
echo

echo
echo "Git object summary:"
git count-objects -vH

echo
echo "Largest tracked files:"
git ls-tree -r -l HEAD | sort -k4 -nr | head -20 | awk '{
    size = $4
    path = $5
    for (i = 6; i <= NF; i++) {
        path = path " " $i
    }
    if (size >= 1048576) {
        printf "  %.1f MiB  %s\n", size / 1048576, path
    } else {
        printf "  %.1f KiB  %s\n", size / 1024, path
    }
}'
