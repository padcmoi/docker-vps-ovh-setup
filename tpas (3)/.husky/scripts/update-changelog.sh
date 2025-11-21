#!/bin/sh
# Generates/updates the changelog:
# - [Unreleased] = commits after the latest tag (feat/fix/refactor/remove)
# - ## vX.Y.Z    = commits between prev_tag..latest_tag (feat/fix/refactor/remove)

set -e

# Optional version override
if [ -n "$1" ]; then
	unreleased_override="$1"
else
	unreleased_override=""
fi

git fetch --tags >/dev/null 2>&1 || true

# Keep sorting by descending creation date (latest tag first)
tags=$(git tag --sort=-creatordate)

latest_tag=$(echo "$tags" | head -n1)
prev_tag=$(echo "$tags" | sed -n '2p')

if [ -z "$latest_tag" ]; then
	echo "Aucun tag trouvé."
	exit 0
fi

########################################
# 1) COMMITS FOR THE CURRENT VERSION
########################################

if [ -z "$prev_tag" ]; then
	range_release="$latest_tag"
else
	range_release="$prev_tag..$latest_tag"
fi

commits_release=$(git log "$range_release" --pretty=format:'%s')

add_rel=""
change_rel=""
remove_rel=""

while IFS= read -r line; do
	case "$line" in
	feat*:*)
		if echo "$line" | grep -qE '^feat\([^)]+\):'; then
			scope=$(echo "$line" | sed -n 's/^feat(\([^)]\+\)):.*$/\1/p')
			msg=$(echo "$line" | sed -n 's/^feat([^)]*):[[:space:]]*//p')
			entry="- ($scope) $msg"
		else
			msg=${line#*: }
			entry="- $msg"
		fi
		if [ -n "$add_rel" ]; then
			add_rel="$add_rel
$entry"
		else
			add_rel="$entry"
		fi
		;;
	fix*:*)
		if echo "$line" | grep -qE '^fix\([^)]+\):'; then
			scope=$(echo "$line" | sed -n 's/^fix(\([^)]\+\)):.*$/\1/p')
			msg=$(echo "$line" | sed -n 's/^fix([^)]*):[[:space:]]*//p')
			entry="- ($scope) $msg"
		else
			msg=${line#*: }
			entry="- $msg"
		fi
		if [ -n "$change_rel" ]; then
			change_rel="$change_rel
$entry"
		else
			change_rel="$entry"
		fi
		;;
	refactor*:*)
		if echo "$line" | grep -qE '^refactor\([^)]+\):'; then
			scope=$(echo "$line" | sed -n 's/^refactor(\([^)]\+\)):.*$/\1/p')
			msg=$(echo "$line" | sed -n 's/^refactor([^)]*):[[:space:]]*//p')
			entry="- ($scope) $msg"
		else
			msg=${line#*: }
			entry="- $msg"
		fi
		if [ -n "$change_rel" ]; then
			change_rel="$change_rel
$entry"
		else
			change_rel="$entry"
		fi
		;;
	remove*:*)
		if echo "$line" | grep -qE '^remove\([^)]+\):'; then
			scope=$(echo "$line" | sed -n 's/^remove(\([^)]\+\)):.*$/\1/p')
			msg=$(echo "$line" | sed -n 's/^remove([^)]*):[[:space:]]*//p')
			entry="- ($scope) $msg"
		else
			msg=${line#*: }
			entry="- $msg"
		fi
		if [ -n "$remove_rel" ]; then
			remove_rel="$remove_rel
$entry"
		else
			remove_rel="$entry"
		fi
		;;
	esac
done <<EOF
$commits_release
EOF

[ -n "$add_rel" ] && add_rel_block="$add_rel" || add_rel_block="-"
[ -n "$change_rel" ] && change_rel_block="$change_rel" || change_rel_block="-"
[ -n "$remove_rel" ] && remove_rel_block="$remove_rel" || remove_rel_block="-"

block_release=$(
	cat <<EOF
## $latest_tag

### Add

$add_rel_block

### Change

$change_rel_block

### Remove

$remove_rel_block
EOF
)

########################################
# 2) COMMITS FOR [Unreleased]
########################################

range_unrel="$latest_tag..HEAD"
commits_unrel=$(git log "$range_unrel" --pretty=format:'%s' || true)

add_unrel=""
change_unrel=""
remove_unrel=""

while IFS= read -r line; do
	case "$line" in
	feat*:*)
		if echo "$line" | grep -qE '^feat\([^)]+\):'; then
			scope=$(echo "$line" | sed -n 's/^feat(\([^)]\+\)):.*$/\1/p')
			msg=$(echo "$line" | sed -n 's/^feat([^)]*):[[:space:]]*//p')
			entry="- ($scope) $msg"
		else
			msg=${line#*: }
			entry="- $msg"
		fi
		if [ -n "$add_unrel" ]; then
			add_unrel="$add_unrel
$entry"
		else
			add_unrel="$entry"
		fi
		;;
	fix*:*)
		if echo "$line" | grep -qE '^fix\([^)]+\):'; then
			scope=$(echo "$line" | sed -n 's/^fix(\([^)]\+\)):.*$/\1/p')
			msg=$(echo "$line" | sed -n 's/^fix([^)]*):[[:space:]]*//p')
			entry="- ($scope) $msg"
		else
			msg=${line#*: }
			entry="- $msg"
		fi
		if [ -n "$change_unrel" ]; then
			change_unrel="$change_unrel
$entry"
		else
			change_unrel="$entry"
		fi
		;;
	refactor*:*)
		if echo "$line" | grep -qE '^refactor\([^)]+\):'; then
			scope=$(echo "$line" | sed -n 's/^refactor(\([^)]\+\)):.*$/\1/p')
			msg=$(echo "$line" | sed -n 's/^refactor([^)]*):[[:space:]]*//p')
			entry="- ($scope) $msg"
		else
			msg=${line#*: }
			entry="- $msg"
		fi
		if [ -n "$change_unrel" ]; then
			change_unrel="$change_unrel
$entry"
		else
			change_unrel="$entry"
		fi
		;;
	remove*:*)
		if echo "$line" | grep -qE '^remove\([^)]+\):'; then
			scope=$(echo "$line" | sed -n 's/^remove(\([^)]\+\)):.*$/\1/p')
			msg=$(echo "$line" | sed -n 's/^remove([^)]*):[[:space:]]*//p')
			entry="- ($scope) $msg"
		else
			msg=${line#*: }
			entry="- $msg"
		fi
		if [ -n "$remove_unrel" ]; then
			remove_unrel="$remove_unrel
$entry"
		else
			remove_unrel="$entry"
		fi
		;;
	esac
done <<EOF
$commits_unrel
EOF

[ -n "$add_unrel" ] && add_unrel_block="$add_unrel" || add_unrel_block="-"
[ -n "$change_unrel" ] && change_unrel_block="$change_unrel" || change_unrel_block="-"
[ -n "$remove_unrel" ] && remove_unrel_block="$remove_unrel" || remove_unrel_block="-"

# Flag: should we display [Unreleased]?
if [ "$add_unrel_block" = "-" ] && [ "$change_unrel_block" = "-" ] && [ "$remove_unrel_block" = "-" ]; then
	show_unrel=0
else
	show_unrel=1
fi

block_unreleased=$(
	cat <<EOF
## ${unreleased_override:-[Unreleased]}

### Add

$add_unrel_block

### Change

$change_unrel_block

### Remove

$remove_unrel_block
EOF
)

########################################
# 3) INIT CHANGELOG IF MISSING
########################################

if [ ! -f CHANGELOG.md ]; then
	cat >CHANGELOG.md <<'EOF'
# CHANGELOG

This file lists the changes by version.

## [Unreleased]

### Add

-

### Change

-

### Remove

-

EOF
fi

########################################
# 4) REWRITE WITH AWK
########################################

tmpfile=$(mktemp)

awk -v ver="$latest_tag" -v block_rel="$block_release" -v block_unrel="$block_unreleased" -v show_unrel="$show_unrel" '
BEGIN {
  inserted_release = 0
  skipping = 0
  seen_first_version = 0
  seen_unreleased = 0
  inserted_unrel = 0
}

# Section [Unreleased]
/^## \[Unreleased\]/ {
  seen_unreleased = 1
  if (show_unrel == 1) {
    print block_unrel
    print ""
    inserted_unrel = 1
  }
  skipping = 1
  next
}

# Any version section "## ..."
/^## / {
  if (skipping) {
    skipping = 0
  }

  # Si on n a pas encore vu [Unreleased] mais qu on doit l afficher,
  # on l insère avant la première version
  if (seen_unreleased == 0 && inserted_unrel == 0 && show_unrel == 1) {
    print block_unrel
    print ""
    inserted_unrel = 1
  }

  # Replace the targeted version
  if ($0 == "## " ver) {
    if (!inserted_release) {
      print block_rel
      print ""
      inserted_release = 1
    }
    skipping = 1
    next
  }

  # If no version has been seen yet, insert the current version first
  if (!seen_first_version && !inserted_release) {
    print block_rel
    print ""
    inserted_release = 1
  }

  seen_first_version = 1
  print
  next
}

# Skip the content of the sections we replace
skipping {
  next
}

# Reste du fichier
{
  print
}

END {
  # Si aucune version insérée (cas limite)
  if (!inserted_release) {
    if (NR > 0) {
      print ""
    }
    print block_rel
    print ""
  }
}
' CHANGELOG.md >"$tmpfile"

mv "$tmpfile" CHANGELOG.md

########################################
# 5) SANITIZE (deduplicate + Prettier format)
########################################

sanitize() {
	tmpclean=$(mktemp)

	awk '
    BEGIN {
        current_version = ""
        current_section = ""
    }

    # Détection version
    /^## / {
        ver = $2
        current_version = ver

        if (!(ver in seen_version)) {
            seen_version[ver] = 1
            order[++order_count] = ver
            add[ver] = ""
            change[ver] = ""
            remove[ver] = ""
        }

        current_section = ""
        next
    }

    # Détection sections
    /^### / {
        if ($2 == "Add") current_section = "Add"
        else if ($2 == "Change") current_section = "Change"
        else if ($2 == "Remove") current_section = "Remove"
        next
    }

    # Items
    /^- / {
        if (current_section == "Add") {
            if (!( $0 in add_seen[current_version] )) {
                add_seen[current_version][$0] = 1
                add[current_version] = add[current_version] $0 "\n"
            }
        }
        if (current_section == "Change") {
            if (!( $0 in change_seen[current_version] )) {
                change_seen[current_version][$0] = 1
                change[current_version] = change[current_version] $0 "\n"
            }
        }
        if (current_section == "Remove") {
            if (!( $0 in remove_seen[current_version] )) {
                remove_seen[current_version][$0] = 1
                remove[current_version] = remove[current_version] $0 "\n"
            }
        }
        next
    }

    END {
        print "# CHANGELOG"
        print ""
        print "This file lists the changes by version."
        print ""

        for (i = 1; i <= order_count; i++) {
            ver = order[i]

            print "## " ver
            print ""

            # ADD
            print "### Add"
            print ""
            if (add[ver] != "")
                printf "%s", add[ver]
            else
                print "-"
            print ""

            # CHANGE
            print "### Change"
            print ""
            if (change[ver] != "")
                printf "%s", change[ver]
            else
                print "-"
            print ""

            # REMOVE
            print "### Remove"
            print ""
            if (remove[ver] != "")
                printf "%s", remove[ver]
            else
                print "-"
            print ""
        }
    }
    ' CHANGELOG.md >"$tmpclean"

	# Remove duplicate empty lines
	awk '
    BEGIN { prev = 0 }
    {
        if ($0 ~ /^$/) {
            if (prev == 1) next
            prev = 1
        } else prev = 0
        print $0
    }
    END {
        # garantit UNE SEULE newline finale
        print ""
    }' "$tmpclean" >CHANGELOG.md

	rm "$tmpclean"
	# Fix EOF: remove trailing empty lines, keep exactly 1 newline
	awk '
    {
        lines[NR] = $0
    }
    END {
        last = NR
        while (last > 1 && lines[last] ~ /^$/) {
            last--
        }
        for (i = 1; i <= last; i++) print lines[i]
   
    }' CHANGELOG.md >"$tmpclean"

	mv "$tmpclean" CHANGELOG.md

}

sanitize
