#!/bin/sh

purge_old_husky_logs() {
	log_dir="$1"
	now_ts="$(date +%s)"
	max_age_days=7
	max_age_seconds=$((max_age_days * 86400))

	for file in "$log_dir"/*.log; do
		[ -e "$file" ] || continue

		filename="$(basename -- "$file")"

		# Extract date YYYY-MM-DD
		log_date="$(echo "$filename" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')"
		[ -z "$log_date" ] && continue

		# Convert YYYY-MM-DD → timestamp
		file_ts="$(date -d "$log_date" +%s 2>/dev/null)" || continue

		age_seconds=$((now_ts - file_ts))

		if [ "$age_seconds" -gt "$max_age_seconds" ]; then
			echo "Suppression ( > 7 jours ) : $file"
			rm -f -- "$file"
		fi
	done
}

purge_old_husky_logs ".husky/logs"
