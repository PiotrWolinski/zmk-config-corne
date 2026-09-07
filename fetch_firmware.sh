#!/usr/bin/env bash

TARGET_PARENT="$1"

# 1. Grab the ID of the most recent run
RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')

if [[ -z "$RUN_ID" ]]; then
  echo "No workflow runs found." >&2
  exit 1
fi

echo "Polling run ID: $RUN_ID"

# 2. Poll every 10 seconds until completed
while true; do
  read -r STATUS CONCLUSION RUN_TIME < <(
    gh run view "$RUN_ID" \
      --json status,conclusion,createdAt \
      --jq '"\(.status) \(.conclusion // "in_progress") \(.createdAt | sub("T"; "_") | sub("Z"; "") | gsub(":"; "-"))"'
  )

  if [[ "$STATUS" == "completed" ]]; then
    if [[ "$CONCLUSION" == "success" ]]; then
      TARGET_DIR="${TARGET_PARENT:+${TARGET_PARENT}/}firmware_${RUN_TIME}"
      
      echo "Run completed successfully! Downloading firmware..."
      gh run download "$RUN_ID" -n firmware --dir "$TARGET_DIR"
      echo "Saved to: $TARGET_DIR"
      exit 0
    else
      echo "Run finished with status: $CONCLUSION" >&2
      exit 1
    fi
  fi

  echo "Run is currently '${STATUS}' (${CONCLUSION}). Checking again in 10s..."
  sleep 10
done