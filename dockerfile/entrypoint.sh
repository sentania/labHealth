#!/bin/bash
set -e

# Check if the runner is already configured
if [ ! -f .runner ]; then
  if [ -z "$REPO_URL" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo "Error: REPO_URL and RUNNER_TOKEN environment variables must be set"
    exit 1
  fi
  echo "Configuring the runner..."
  ./config.sh --url "$REPO_URL" --token "$RUNNER_TOKEN" --unattended
fi

# Start the runner
echo "Starting the runner..."
./run.sh
