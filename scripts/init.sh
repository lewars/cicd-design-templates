#!/bin/bash

# This script creates an initial layout

# Define the directory structure
DIRS=(
    "apps/web-services/example-app/src"
    "build-tools/cmake"
    "build-tools/make"
    "build-tools/taskfile"
    "data-platforms/databricks/bundles/project-x/resources"
    "data-platforms/databricks/bundles/project-x/targets"
    "data-platforms/databricks/notebooks"
    "data-platforms/databricks/src"
    "data-platforms/databricks/tests"
    "docs"
    "infrastructure/cloud"
    "infrastructure/on-prem"
    "kubernetes/base"
    "kubernetes/charts"
    "kubernetes/clusters/staging"
    "kubernetes/clusters/production"
    "ml-ai/hardware"
    "ml-ai/software"
    "platforms/github-actions"
    "platforms/jenkins"
    "platforms/runners"
    "scripts"
)

echo "Creating directory structure in $(pwd)..."

# Create directories and add .gitkeep
for dir in "${DIRS[@]}"; do
    mkdir -vp "$dir"
    touch "$dir/.gitkeep"
done

# Initialize git if not already present
if [ ! -d ".git" ]; then
    git init
    echo "Initialized empty Git repository."
fi

echo "Done. All directories created with .gitkeep files."
