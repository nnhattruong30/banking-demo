# Helm Chart

## Structure

Each service is a subchart in `charts/<name>/` with its own Chart.yaml and values.yaml.
Subchart: postgres, redis, kong, auth-service, account-service, transfer-service, notification-service, frontend.
Override a key in subchart: `--set postgres.storage.size=2Gi`

Release namespace: {{ .Release.Namespace }}
Ingress host: {{ .Values.ingress.host | default "npd-banking.co" }}

## CLIs

Install: `helm install banking-demo . -n banking --create-namespace`
Upgrade: `helm upgrade banking-demo . -n banking`
Disable a service: `helm upgrade banking-demo . -n banking --set postgres.enabled=false`
