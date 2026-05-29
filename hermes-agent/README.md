# Hermes Agent

This RO-Crate defines a generic OSCAR agent runtime based on Hermes Agent. The
same service can be invoked synchronously with an input file or asynchronously
when a user uploads a file to the configured input bucket path. Each invocation
configures Hermes with the selected model provider, passes the deployed behavior
instructions, and writes Hermes' final response as a text result.

## Files

- `Dockerfile`: derives from the Hermes Agent image and adds common file
  processing utilities.
- `fdl.yml`: OSCAR service definition for the agent runtime.
- `script.sh`: service execution script run by the FaaS Supervisor.
- `SOUL.md`: human-readable behavior contract for the agent.
- `ro-crate-metadata.json`: RO-Crate metadata for cataloging the agent.

## Model provider configuration

The sample FDL is configured for an OpenAI-compatible EGI provider:

```yaml
environment:
  variables:
    HERMES_PROVIDER_NAME: egi
    OPENAI_BASE_URL: https://llm.ai.egi.eu/v1
    OPENAI_MODEL: agentic
  secrets:
    OPENAI_API_KEY: change-me
```

Replace `OPENAI_API_KEY` with an OSCAR secret value at deployment time. Do not
commit real API keys.

The behavior of the deployed agent is provided through `AGENT_SOUL` in
`fdl.yml`. `SOUL.md` keeps the same contract in a readable, catalogable form.

## Build the image

Edit the image name in `fdl.yml`, then build and push the image:

```bash
docker build -t YOUR_REGISTRY/hermes-agent:latest .
docker push YOUR_REGISTRY/hermes-agent:latest
```

## Deploy

```bash
oscar-cli apply fdl.yml
```

The service watches:

```text
hermes-agent/input
```

and writes processing results to:

```text
hermes-agent/output
```

## Run synchronously

Invoke the service directly with a local file:

```bash
oscar-cli service run hermes-agent --file-input ./input-file --decode-output --output ./input-file-result.txt
```

## Run asynchronously

Upload a file to trigger an asynchronous execution:

```bash
oscar-cli service put-file hermes-agent minio.default ./input-file hermes-agent/input/input-file
```

Download the generated result:

```bash
oscar-cli service get-file hermes-agent minio.default hermes-agent/output/input-file-result.txt ./input-file-result.txt
```
