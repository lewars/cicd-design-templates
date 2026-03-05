#!/bin/bash
# scripts/notify.sh
# Posts an Adaptive Card to an MS Teams webhook channel.
#
# Usage:
#   bash scripts/notify.sh \
#     --status "Success" \
#     --env "prod" \
#     --bundle "marketing_analytics" \
#     --version "1.4.2" \
#     --run-url "https://github.com/org/repo/actions/runs/123456789" \
#     --webhook-url "https://outlook.office.com/webhook/..."

set -euo pipefail

STATUS=""
ENV=""
BUNDLE=""
VERSION=""
RUN_URL=""
WEBHOOK_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)      STATUS="$2";      shift 2 ;;
    --env)         ENV="$2";         shift 2 ;;
    --bundle)      BUNDLE="$2";      shift 2 ;;
    --version)     VERSION="$2";     shift 2 ;;
    --run-url)     RUN_URL="$2";     shift 2 ;;
    --webhook-url) WEBHOOK_URL="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

MISSING=()
[[ -z "$STATUS" ]]      && MISSING+=("--status")
[[ -z "$ENV" ]]         && MISSING+=("--env")
[[ -z "$BUNDLE" ]]      && MISSING+=("--bundle")
[[ -z "$VERSION" ]]     && MISSING+=("--version")
[[ -z "$RUN_URL" ]]     && MISSING+=("--run-url")
[[ -z "$WEBHOOK_URL" ]] && MISSING+=("--webhook-url")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: missing required arguments: ${MISSING[*]}" >&2
  exit 1
fi

case "${STATUS,,}" in
  success) EMOJI="✅"; COLOR="Good" ;;
  failed|failure) EMOJI="❌"; COLOR="Attention" ;;
  *) EMOJI="ℹ️";  COLOR="Accent" ;;
esac

TITLE="${EMOJI} Deployment ${STATUS}: ${BUNDLE}"

PAYLOAD=$(cat <<EOF
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "contentUrl": null,
      "content": {
        "\$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.4",
        "body": [
          {
            "type": "TextBlock",
            "text": "${TITLE}",
            "weight": "Bolder",
            "size": "Medium",
            "color": "${COLOR}",
            "wrap": true
          },
          {
            "type": "FactSet",
            "facts": [
              { "title": "Bundle",      "value": "${BUNDLE}" },
              { "title": "Environment", "value": "${ENV}" },
              { "title": "Version",     "value": "${VERSION}" },
              { "title": "Status",      "value": "${STATUS}" }
            ]
          },
          {
            "type": "ActionSet",
            "actions": [
              {
                "type": "Action.OpenUrl",
                "title": "View Actions Run",
                "url": "${RUN_URL}"
              }
            ]
          }
        ]
      }
    }
  ]
}
EOF
)

HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" \
  "${WEBHOOK_URL}")

if [[ "${HTTP_STATUS}" -ne 200 && "${HTTP_STATUS}" -ne 202 ]]; then
  echo "Error: Teams webhook returned HTTP ${HTTP_STATUS}" >&2
  exit 1
fi

echo "Notification sent (HTTP ${HTTP_STATUS}): ${TITLE}"
