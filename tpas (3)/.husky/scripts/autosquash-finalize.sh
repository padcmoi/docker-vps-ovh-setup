#!/usr/bin/env sh
set -e

# Read the final tag (already created by your hooks)
VERSION=$(cat .husky/GITFLOW_TAG_VERSION 2>/dev/null || echo "")

# If no version, nothing to do
if [ -z "$VERSION" ]; then
	exit 0
fi

# Detect if it's a release or a hotfix
BRANCH=$(git rev-parse --abbrev-ref HEAD)

if echo "$BRANCH" | grep -q "main"; then
	TYPE="release"
elif echo "$BRANCH" | grep -q "hotfix"; then
	TYPE="hotfix"
else
	# Not the end of a release/hotfix → exit
	exit 0
fi

echo "[HUSKY] Autosquash FINAL → cleaning flow ($TYPE $VERSION)"

# Go back up to 10 commits max
N=10

# Keep the main commit as pick, convert others to fixup
GIT_SEQUENCE_EDITOR="sh -c 'sed -i \"1!s/^pick /fixup /\" \"$1\"'" \
	git rebase -i --autosquash --no-edit HEAD~"$N" || true

# Rename the final commit
git commit --amend -m "$TYPE: $TYPE $VERSION" || true

# Safe push
git push --force-with-lease || true
git push --tags || true

echo "[HUSKY] Autosquash FINAL OK."
