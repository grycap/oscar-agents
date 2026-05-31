#!/bin/sh
set -eu

HERMES_BIN="${HERMES_BIN:-/opt/hermes/.venv/bin/hermes}"

if [ -z "${INPUT_FILE_PATH:-}" ]; then
  echo "INPUT_FILE_PATH is not set" >&2
  exit 1
fi

if [ -z "${TMP_OUTPUT_DIR:-}" ]; then
  echo "TMP_OUTPUT_DIR is not set" >&2
  exit 1
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "OPENAI_API_KEY is not set" >&2
  exit 1
fi

export OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
export OPENAI_MODEL="${OPENAI_MODEL:-gpt-4o-mini}"
export LLM_PROVIDER_NAME="${LLM_PROVIDER_NAME:-${HERMES_PROVIDER_NAME:-openai-compatible}}"
export AGENT_SOUL="${AGENT_SOUL:-You are an OSCAR agent. Process the provided input file according to the deployment instructions and return the final result.}"
export AGENT_SKILLS="${AGENT_SKILLS:-}"
export HERMES_HOME="${HERMES_HOME:-/tmp/hermes-home}"
export HOME="${HOME:-/tmp}"

mkdir -p "$TMP_OUTPUT_DIR"
mkdir -p "$HERMES_HOME"

input_name="$(basename "$INPUT_FILE_PATH")"
base_name="${input_name%.*}"
output_file="$TMP_OUTPUT_DIR/${base_name}-result.txt"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

echo "Hermes OSCAR agent processor"
echo "Provider: $LLM_PROVIDER_NAME"
echo "Model: $OPENAI_MODEL"
echo "Input: $INPUT_FILE_PATH"
echo "Output: $output_file"

if [ ! -x "$HERMES_BIN" ]; then
  echo "Hermes executable not found at $HERMES_BIN" >&2
  exit 1
fi

cat > "$HERMES_HOME/config.yaml" <<EOF
custom_providers:
  - name: ${LLM_PROVIDER_NAME}
    base_url: ${OPENAI_BASE_URL}
    api_key: ${OPENAI_API_KEY}
    model: ${OPENAI_MODEL}
model: ${OPENAI_MODEL}
provider: ${LLM_PROVIDER_NAME}
hooks_auto_accept: true
EOF
chmod 600 "$HERMES_HOME/config.yaml"

cp "$INPUT_FILE_PATH" "$workspace/$input_name"

query=$(cat <<EOF
${AGENT_SOUL}

Available reusable skills:
${AGENT_SKILLS}

Task:
The input file to be processed is available at:
${workspace}/${input_name}

Use the file and terminal tools as needed to inspect and process the file
according to the instructions above.
Return only the final result content.
EOF
)

(
  cd "$workspace"
  "$HERMES_BIN" chat \
    -t file,terminal \
    -q "$query" \
    --provider "$LLM_PROVIDER_NAME" \
    -m "$OPENAI_MODEL" \
    -Q \
    --accept-hooks \
    --source oscar
) > "$output_file"

echo "Result written to $output_file"
