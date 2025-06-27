{{/*
Create chart name and version as used by the chart label.
Note: Because this is used as a label, we ensure the label restrictions here:
- starts and ends with an alphanumeric character;
- only accepts `-`, `_`, and `.` special characters (hence the replace of `+` which might be present in versions);
- char limit of 63.
*/}}
{{- define "monitoring.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "monitoring.labels" -}}
helm.sh/chart: {{ include "monitoring.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
vendor: crunchydata
{{- end }}

{{/*
Alertmanager selector labels
Defined with labels that shouldn't change since this is an immutable field
*/}}
{{- define "alertmanager.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: crunchy-alertmanager
{{- end }}

{{/*
Alertmanager labels
*/}}
{{- define "alertmanager.labels" -}}
{{ include "monitoring.labels" . }}
{{ include "alertmanager.selectorLabels" . }}
{{- if .Values.alertmanager.labels }}
{{ .Values.alertmanager.labels | toYaml }}
{{- end }}
{{- end }}

{{/*
Grafana selector labels
Defined with labels that shouldn't change since this is an immutable field
*/}}
{{- define "grafana.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: crunchy-grafana
{{- end }}

{{/*
Grafana labels
*/}}
{{- define "grafana.labels" -}}
{{ include "monitoring.labels" . }}
{{ include "grafana.selectorLabels" . }}
{{- if .Values.grafana.labels }}
{{ .Values.grafana.labels | toYaml }}
{{- end }}
{{- end }}

{{/*
Prometheus selector labels
Defined with labels that shouldn't change since this is an immutable field
*/}}
{{- define "prometheus.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: crunchy-prometheus
{{- end }}

{{/*
Prometheus labels
*/}}
{{- define "prometheus.labels" -}}
{{ include "monitoring.labels" . }}
{{ include "prometheus.selectorLabels" . }}
{{- if .Values.prometheus.labels }}
{{ .Values.prometheus.labels | toYaml }}
{{- end }}
{{- end }}
