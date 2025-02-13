#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 1. Pre-requisites and Environment Setup
# -----------------------------------------------------------------------------

# Ensure required environment variables are set.
if [[ -z "${ARIA_AUTOMATION_USERNAME:-}" || -z "${ARIA_AUTOMATION_PASSWORD:-}" || -z "${ARIA_AUTOMATION_HOST:-}" ]]; then
  echo "Please set ARIA_AUTOMATION_USERNAME, ARIA_AUTOMATION_PASSWORD, and ARIA_AUTOMATION_HOST."
  exit 1
fi

# Set the ARIA Automation URL.
export ARIA_AUTOMATION_URL="https://${ARIA_AUTOMATION_HOST}"

# Check that jq is installed.
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed. Please install jq and try again."
  exit 1
fi

# -----------------------------------------------------------------------------
# 2. Authentication: Get Refresh Token and then Bearer Token
# -----------------------------------------------------------------------------

echo "Obtaining refresh token..."
# Call the support script to get the refresh token.
REFRESH_TOKEN=$(./support_scripts/get_refresh_token.sh --username "$ARIA_AUTOMATION_USERNAME" --password "$ARIA_AUTOMATION_PASSWORD" --url "$ARIA_AUTOMATION_HOST")

if [[ -z "$REFRESH_TOKEN" || "$REFRESH_TOKEN" == "null" ]]; then
  echo "Failed to obtain refresh token."
  exit 1
fi
echo "Refresh token obtained."

echo "Obtaining bearer token using the refresh token..."
# Based on Broadcom's Knowledge article 346005, the correct endpoint for generating the bearer token is:
#  /iaas/api/login
# and the response JSON contains the property "bearerToken".
bearer_response=$(curl -s -k -X POST "${ARIA_AUTOMATION_URL}/iaas/api/login" \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\": \"$REFRESH_TOKEN\"}")

BEARER_TOKEN=$(echo "$bearer_response" | jq -r '.token')

if [[ -z "$BEARER_TOKEN" || "$BEARER_TOKEN" == "null" ]]; then
  echo "Failed to obtain bearer token. Response:"
  echo "$bearer_response"
  exit 1
fi
echo "Bearer token obtained successfully."

# -----------------------------------------------------------------------------
# 3. Catalog Deployment Section
# -----------------------------------------------------------------------------

# Define the directory containing input JSON files (at the repository root).
INPUT_DIR="./aria_inputs"

if [ ! -d "$INPUT_DIR" ]; then
  echo "Input directory '$INPUT_DIR' does not exist. Exiting."
  exit 1
fi

# Get the current date (for deployment naming and reason).
CURRENT_DATE=$(date +'%Y-%m-%d')

# Loop through each JSON file in the input directory.
for input_file in "$INPUT_DIR"/*.json; do
  echo "Processing file: $input_file"

  # Extract values from the input file (using camelCase keys as expected by the API).
  catalogItemId=$(jq -r '.catalogItemId' "$input_file")
  catalogItemInputs=$(jq -c '.catalogItemInputs' "$input_file")
  projectId=$(jq -r '.projectId' "$input_file")
  catalogVersion=$(jq -r '.catalogVersion' "$input_file")
  bpName=$(jq -r '.bpName' "$input_file")

  # Calculate a deployment name: replace spaces with underscores and append the date.
  deploymentName="${bpName}-$(date +'%Y%m%d')"
  
  # Create a reason string.
  reason="Daily Check ${CURRENT_DATE}"


  echo "Deploying catalog item: ${catalogItemId}"
  echo "Deployment Name: ${deploymentName}"
  echo "Reason: ${reason}"

  # Construct the JSON payload for the catalog API.
  payload=$(jq -n \
    --arg catalogItemId "$catalogItemId" \
    --argjson catalogItemInputs "$catalogItemInputs" \
    --arg projectId "$projectId" \
    --arg catalogVersion "$catalogVersion" \
    --arg deploymentName "$deploymentName" \
    --arg reason "$reason" \
    '{
       catalogItemId: $catalogItemId,
       catalogItemInputs: $catalogItemInputs,
       projectId: $projectId,
       catalogVersion: $catalogVersion,
       deploymentName: $deploymentName,
       reason: $reason
     }'
  )

  # Submit the catalog request using the bearer token for authentication.
  response=$(curl -s -w "\n%{http_code}" -X POST "${ARIA_AUTOMATION_URL}/catalog/api/items/${catalogItemId}/request" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${BEARER_TOKEN}" \
    -d "$payload"
  )

  # Separate HTTP status code from response body.
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ne 200 ]; then
    echo "Error deploying catalog item '${catalogItemId}'. HTTP code: $http_code"
    echo "Response: $body"
    exit 1
  else
    echo "Successfully deployed catalog item '${catalogItemId}'."
  fi
done

echo "All deployments triggered successfully."
