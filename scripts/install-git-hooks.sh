#!/bin/sh
set -eu

git config core.hooksPath scripts/git-hooks
echo "Git hooks enabled from scripts/git-hooks"
