# Lab Health Check & Catalog Deployment Automation

This repository contains scripts and configurations to automate catalog deployments in an ARIA Automation environment using a GitHub Actions self‑hosted runner. The solution triggers deployments based on input files and continuously polls for deployment status until completion.

## Overview

The project performs the following tasks:
- **Authentication:** Retrieves a refresh token using a support script, then obtains a bearer token for API requests.
- **Deployment Triggering:** Reads JSON input files to trigger catalog item deployments via the ARIA Automation API.
- **Status Monitoring:** Polls the deployment status periodically until it reports `"CREATE_SUCCESSFUL"`, or exits on failure or timeout.

## Pre-requisites

- **Repository Secrets:**  
  Configure the following secrets in your repository settings (under **Settings > Secrets and variables > Actions**):
  - `ARIA_AUTOMATION_USERNAME`
  - `ARIA_AUTOMATION_PASSWORD`
  - `ARIA_AUTOMATION_HOST`

- **Software Requirements:**
  - [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/) (if using the self‑hosted runner in a container)
  - The `jq` utility is installed in the container (see the Dockerfile)
  - A GitHub Actions self‑hosted runner configured for your repository

## Folder Structure

Below is the recommended folder structure for the project:

```plaintext
/<repo-root>
├── aria_inputs/              # Input JSON files for catalog deployments.
├── scripts/
│   └── aria_deploy_check.sh  # Main script to trigger and monitor deployments.
├── support_scripts/
│   └── get_refresh_token.sh  # Script to obtain a refresh token for authentication.
├── .github/
│   └── workflows/
│       └── health-check.yml  # GitHub Actions workflow file for scheduled health checks.
├── Dockerfile                # Dockerfile for the self‑hosted runner image.
├── docker-compose.yml        # Docker Compose file to run the self‑hosted runner.
└── README.md                 # This file.```
## How It Works

1. **Authentication**  
   The script in `support_scripts/get_refresh_token.sh` obtains a refresh token using ARIA Automation credentials. This token is then used to generate a bearer token required for API requests.

2. **Triggering Deployments**  
   The script in `scripts/aria_deploy_check.sh` reads input JSON files (located in `aria_inputs/`) which define:
   - `catalogItemId`
   - `catalogItemInputs`
   - `projectId`
   - `catalogVersion`
   - `bpName` (used to generate a deployment name)
   
   It constructs a deployment payload and submits a request to the ARIA Automation API endpoint:
   
```bash
   ${ARIA_AUTOMATION_URL}/catalog/api/items/${catalogItemId}/request
```

3; **Monitoring Deployment Status**
    After triggering a deployment, the script extracts the deploymentId from the response and polls the deployment status at:

```bash
${ARIA_AUTOMATION_URL}/deployment/api/deployments/${deploymentId}
```

It checks the status field until it changes to "CREATE_SUCCESSFUL", or exits if the status is "FAILED" or times out.

4. **Workflow Integration**
    A GitHub Actions workflow (defined in .github/workflows/health-check.yml) runs the aria_deploy_check.sh script on a schedule or manually.

Usage
Input Files:
Update the JSON files in the aria_inputs/ folder as needed. An example input file looks like this:

```json

{
  "catalogItemId": "b771efae-5ecb-3760-a934-38d687a7e4c8",
  "catalogItemInputs": {
    "inputParameter1": "value1",
    "inputParameter2": "value2"
  },
  "projectId": "eac08244-dce0-420b-b4cc-3faf5e51756e",
  "catalogVersion": "1",
  "bpName": "Daily Test Postman"
}
```

## Runner Setup:
Build and run your self‑hosted runner using Docker Compose:

```bash

docker-compose up --build -d
```

## Workflow Execution:
The GitHub Actions workflow will execute the aria_deploy_check.sh script according to its schedule or via manual trigger in the Actions tab.

## Contributing
Contributions and improvements are welcome! Please open an issue or submit a pull request with your suggestions.

## License
This project is licensed under the MIT License. See the LICENSE file for details.