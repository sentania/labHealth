#!/bin/bash
#
# Script to generate a refresh token for vRA8 on-prem or vRA Cloud.
# This script requires:
#   --username : Your vRA username.
#   --password : Your vRA password.
#   --url      : The hostname/FQDN of your vRA server.
#
# It sets the environment variable VRA_REFRESH_TOKEN and echoes it.
# Requires the jq utility.
#

# Initialize variables.
username=""
password=""
host=""

# Parse command-line arguments.
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --username)
      username="$2"
      shift # past argument
      shift # past value
      ;;
    --password)
      password="$2"
      shift
      shift
      ;;
    --url)
      host="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate parameters.
if [[ -z "$username" ]]; then
  echo "Error: --username is required."
  exit 1
fi

if [[ -z "$password" ]]; then
  echo "Error: --password is required."
  exit 1
fi

if [[ -z "$host" ]]; then
  echo "Error: --url is required."
  exit 1
fi

# Check that jq is installed.
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is not installed. Please install jq (https://stedolan.github.io/jq/)."
  exit 1
fi

# Set the VRA_URL using the host.
export VRA_URL="https://$host"

# Obtain the refresh token using the vRA-style authentication endpoint.
response=$(curl -sk -X POST "$VRA_URL/csp/gateway/am/api/login?access_token" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$username\",\"password\":\"$password\"}")

VRA_REFRESH_TOKEN=$(echo "$response" | jq -r '.refresh_token')

if [[ -z "$VRA_REFRESH_TOKEN" || "$VRA_REFRESH_TOKEN" == "null" ]]; then
  echo "Error: Failed to obtain refresh token. Response:"
  echo "$response"
  exit 1
fi

export VRA_REFRESH_TOKEN

# Clean up sensitive data.
unset password

echo "$VRA_REFRESH_TOKEN"
