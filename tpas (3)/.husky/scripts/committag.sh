#!/usr/bin/env sh

# Fonction pour récupérer la branche courante,
# le dernier message de commit et le dernier tag
get_commit_and_tag() {
	# git fetch --tags >/dev/null 2>&1 || true

	# Keep sorting by descending creation date (latest tag first)
	tags=$(git tag --sort=-creatordate)

	latest_tag=$(echo "$tags" | head -n1)
	prev_tag=$(echo "$tags" | sed -n '2p')

	COMMIT_MSG=""
	LAST_TAG=""
	CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
	CURRENT_HASH=$(git rev-parse HEAD)

	if [ -f .git/MERGE_HEAD ]; then
		MERGE_REF=$(cat .git/MERGE_HEAD)
		COMMIT_MSG=$(git log -1 --format="%s" "$MERGE_REF")
		LAST_TAG=$(git describe --tags --abbrev=0 "$MERGE_REF" 2>/dev/null || echo 'No tag found')
	else
		COMMIT_MSG=$(git log -1 --format="%s")
		LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo 'No tag found')
	fi

	echo "$CURRENT_HASH | $COMMIT_MSG | $LAST_TAG | $prev_tag > $latest_tag | $CURRENT_BRANCH | $(basename "$0")" >>".husky/logs/_sequence.$(date '+%Y-%m-%d').log"

}
