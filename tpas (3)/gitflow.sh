#!/usr/bin/env sh
set -eu

TAG_FILE=".husky/GITFLOW_TAG_VERSION"
START_FILE=".husky/GITFLOW_START_HASH"
CHANGELOG_SCRIPT=".husky/scripts/update-changelog.sh"

usage() {
	echo "USAGE:"
	echo "  ./gitflow.sh release init <version>"
	echo "  ./gitflow.sh release finish"
	echo "  ./gitflow.sh hotfix init <version>"
	echo "  ./gitflow.sh hotfix finish"
	exit 0
}

metadata() {
	VERSION="$1"

	echo "$VERSION" >"$TAG_FILE"
	echo "$START_HASH" >"$START_FILE"

	git add "$TAG_FILE" "$START_FILE"

	if [ -f "$CHANGELOG_SCRIPT" ]; then
		sh "$CHANGELOG_SCRIPT" || true
		git add CHANGELOG.md || true
	fi

	git commit -m "chore: persist metadata v$VERSION" --no-verify --no-edit || true
	git push --force-with-lease || true
}

release_init() {
	VERSION="$1"

	git flow release start "$VERSION" || true
	git commit --allow-empty -m "Version bump to $VERSION" --no-verify --no-edit

	START_HASH="$(git rev-parse HEAD)"

	metadata "$VERSION"
}

release_finish() {
	BRANCH="$(git rev-parse --abbrev-ref HEAD)"
	VERSION="${BRANCH#release/}"

	git flow release finish "$VERSION" -m "release: $VERSION" || true

	git checkout main || git checkout master
	BASE_HASH="$(cat "$START_FILE")"

	git reset --soft "${BASE_HASH}^"
	git commit -m "release: $VERSION" --no-verify --no-edit

	git tag -f "$VERSION"
	git push --force-with-lease
	git push --force origin "$VERSION"
}

hotfix_init() {
	VERSION="$1"

	git flow hotfix start "$VERSION" || true
	git commit --allow-empty -m "Version bump to $VERSION" --no-verify --no-edit

	START_HASH="$(git rev-parse HEAD)"

	metadata "$VERSION"
}

hotfix_finish() {
	BRANCH="$(git rev-parse --abbrev-ref HEAD)"
	VERSION="${BRANCH#hotfix/}"

	git flow hotfix finish "$VERSION" -m "hotfix: $VERSION" || true

	git checkout main || git checkout master
	BASE_HASH="$(cat "$START_FILE")"

	git reset --soft "${BASE_HASH}^"
	git commit -m "hotfix: $VERSION" --no-verify --no-edit

	git tag -f "$VERSION"
	git push --force-with-lease
	git push --force origin "$VERSION"
}

MODE="${1:-}"
ACTION="${2:-}"
VALUE="${3:-}"

[ -z "$MODE" ] && usage
[ -z "$ACTION" ] && usage

case "$MODE" in
release)
	case "$ACTION" in
	init) release_init "$VALUE" ;;
	finish) release_finish ;;
	*) usage ;;
	esac
	;;
hotfix)
	case "$ACTION" in
	init) hotfix_init "$VALUE" ;;
	finish) hotfix_finish ;;
	*) usage ;;
	esac
	;;
*) usage ;;
esac
