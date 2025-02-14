#!/bin/bash
set -euo pipefail

# Define the CSV file location in the 'url_inputs' directory at the repository root.
CSV_FILE="../url_inputs/urls.csv"

if [ ! -f "$CSV_FILE" ]; then
  echo "CSV file '$CSV_FILE' not found. Exiting."
  exit 1
fi

echo "Starting URL checks based on CSV file: $CSV_FILE"

# Process each line in the CSV file.
while IFS=, read -r fqdn expected_code search_text; do
  # Skip empty lines or lines beginning with #
  if [[ -z "$fqdn" ]] || [[ "$fqdn" =~ ^\s*# ]]; then
    continue
  fi

  # Trim whitespace from variables.
  fqdn=$(echo "$fqdn" | xargs)
  expected_code=$(echo "$expected_code" | xargs)
  search_text=$(echo "$search_text" | xargs)

  echo "-------------------------------------------"
  echo "Checking URL: $fqdn"

  # Use curl to fetch the URL, ignoring SSL certificate issues.
  response=$(curl -s -k -w "\nHTTP_CODE:%{http_code}" "$fqdn")

  # Extract the HTTP code and body.
  http_code=$(echo "$response" | tail -n1 | cut -d: -f2)
  body=$(echo "$response" | sed '$d')

  echo "HTTP Code: $http_code (expected: $expected_code)"

  if [ "$http_code" -ne "$expected_code" ]; then
    echo "FAILURE: Expected HTTP code $expected_code but got $http_code."
  else
    # Search for the expected text in the body.
    if echo "$body" | grep -q "$search_text"; then
      echo "SUCCESS: Expected text '$search_text' found in the response."
    else
      echo "FAILURE: Expected text '$search_text' NOT found in the response."
    fi
  fi
done < "$CSV_FILE"

echo "URL checks completed."
