#!/usr/bin/env bash

mkdir -p "$PROJECTS_DIR"
cd "$PROJECTS_DIR"

for repo in $(gh repo list $GITHUB_USERNAME --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'); do
    echo "Cloning $repo..."
    gh repo clone "$repo" || echo "Already exists or failed: $repo"
done

for repo in $(gh repo list $GITHUB_ORG --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'); do
    echo "Cloning $repo..."
    gh repo clone "$repo" || echo "Already exists or failed: $repo"
done
