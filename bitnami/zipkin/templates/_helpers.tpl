{{/*
Copyright Broadcom, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Return the proper zipkin image name
*/}}
{{- define "zipkin.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper image name (for the wait init container)
*/}}
{{- define "zipkin.init-containers.wait.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.defaultInitContainers.waitForCassandra.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "zipkin.imagePullSecrets" -}}
{{- include "common.images.renderPullSecrets" (dict "images" (list .Values.image .Values.defaultInitContainers.waitForCassandra.image) "context" $) -}}
{{- end -}}

{{/*
Create the cassandra host
*/}}
{{- define "zipkin.cassandra.host" -}}
    {{- if not .Values.cassandra.enabled -}}
        {{- .Values.externalDatabase.host -}}
    {{- else -}}
        {{- include "common.names.dependency.fullname" (dict "chartName" "cassandra" "chartValues" .Values.cassandra "context" $) -}}
    {{- end }}
{{- end }}

{{/*
Return the cassandra Port
*/}}
{{- define "zipkin.cassandra.port" -}}
{{- if .Values.cassandra.enabled }}
    {{- print .Values.cassandra.service.ports.cql -}}
{{- else -}}
    {{- printf "%d" (.Values.externalDatabase.port | int ) -}}
{{- end -}}
{{- end -}}

{{/*
Return the cassandra datacenter
*/}}
{{- define "zipkin.cassandra.datacenter" -}}
{{- if .Values.cassandra.enabled }}
    {{- print .Values.cassandra.cluster.datacenter -}}
{{- else -}}
    {{- print .Values.externalDatabase.cluster.datacenter -}}
{{- end -}}
{{- end -}}

{{/*
Return the cassandra Database Name
*/}}
{{- define "zipkin.cassandra.keyspace" -}}
{{- if .Values.keyspace }}
    {{- /* Inside cassandra subchart */ -}}
    {{- print .Values.keyspace -}}
{{- else if .Values.cassandra.enabled }}
    {{- print .Values.cassandra.keyspace -}}
{{- else -}}
    {{- print .Values.externalDatabase.keyspace -}}
{{- end -}}
{{- end -}}

{{/*
Return the cassandra User
*/}}
{{- define "zipkin.cassandra.user" -}}
{{- if .Values.cassandra.enabled }}
    {{- print .Values.cassandra.dbUser.user -}}
{{- else -}}
    {{- print .Values.externalDatabase.user -}}
{{- end -}}
{{- end -}}

{{/*
Return the cassandra Secret Name
*/}}
{{- define "zipkin.cassandra.secretName" -}}
{{- if .Values.cassandra.enabled }}
    {{- if .Values.cassandra.dbUser.existingSecret -}}
        {{- print (tpl .Values.cassandra.dbUser.existingSecret .) -}}
    {{- else -}}
        {{- print (include "zipkin.cassandra.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalDatabase.existingSecret -}}
    {{- print (tpl .Values.externalDatabase.existingSecret .) -}}
{{- else -}}
    {{- printf "%s-%s" (include "common.names.fullname" .) "externaldb" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the database password key
*/}}
{{- define "zipkin.cassandra.passwordKey" -}}
{{- if .Values.cassandra.enabled -}}
    {{- print "cassandra-password" -}}
{{- else -}}
    {{- print .Values.externalDatabase.existingSecretPasswordKey -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "zipkin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Extra configuration ConfigMap name
*/}}
{{- define "zipkin.configmapName" -}}
{{- if .Values.existingConfigmap -}}
    {{- tpl .Values.existingConfigmap $ -}}
{{- else -}}
    {{- include "common.names.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Default configuration Secret name
*/}}
{{- define "zipkin.secretName" -}}
{{- if .Values.existingSecret -}}
    {{- tpl .Values.existingSecret $ -}}
{{- else -}}
    {{- include "common.names.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a TLS credentials secret object should be created
*/}}
{{- define "zipkin.tls.createSecret" -}}
{{- if and .Values.tls.enabled .Values.tls.autoGenerated.enabled (not .Values.tls.existingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the TLS credentials secret
*/}}
{{- define "zipkin.tls.secretName" -}}
{{- if .Values.tls.existingSecret -}}
    {{- print (tpl .Values.tls.existingSecret $) -}}
{{- else -}}
    {{- printf "%s-crt" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the JKS password secret name
*/}}
{{- define "zipkin.tls.passwordSecretName" -}}
{{- $secretName := .Values.tls.passwordSecret -}}
{{- if $secretName -}}
    {{- printf "%s" (tpl $secretName $) -}}
{{- else -}}
    {{- printf "%s-tls-pass" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified cassandra name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "zipkin.cassandra.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "cassandra" "chartValues" .Values.cassandra "context" $) -}}
{{- end -}}

{{/*
Compile all warnings into a single message.
*/}}
{{- define "zipkin.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "zipkin.validateValues.cassandra" .) -}}
{{- $messages := append $messages (include "zipkin.validateValues.extraVolumes" .) -}}
{{- $messages := append $messages (include "zipkin.validateValues.tls" .) -}}
{{- $messages := append $messages (include "zipkin.validateValues.storage" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "\nVALUES VALIDATION:\n%s" $message -}}
{{- end -}}
{{- end -}}

{{/*
Validate values of zipkin - At least one storage backend is enabled
*/}}
{{- define "zipkin.validateValues.cassandra" -}}
{{- if and (eq .Values.storageType "cassandra3") (not .Values.cassandra.enabled) (not .Values.externalDatabase.host) -}}
zipkin: cassandra
    Storage type is set to cassandra3 but database is not configured. Please set cassandra.enabled=true or configure the externalDatabase section.
{{- end -}}
{{- end -}}

{{/* Validate values of zipkin - Incorrect extra volume settings */}}
{{- define "zipkin.validateValues.extraVolumes" -}}
{{- if and .Values.extraVolumes (not .Values.extraVolumeMounts) -}}
zipkin: missing-extra-volume-mounts
    You specified extra volumes but not mount points for them. Please set
    the extraVolumeMounts value
{{- end -}}
{{- end -}}

{{/*
Validate values of zipkin - TLS
*/}}
{{- define "zipkin.validateValues.tls" -}}
{{- if and .Values.tls.enabled .Values.tls.autoGenerated.enabled -}}
{{- if or (not (empty .Values.tls.certFilename)) (not (empty .Values.tls.certKeyFilename)) -}}
zipkin: tls.autoGenerated
    When enabling auto-generated TLS certificates, all certificate and key fields must be empty.
    Please disable auto-generated TLS certificates (--set tls.autoGenerated.enabled=false) or
    remove the certificate and key fields.
{{- end -}}
{{- if .Values.tls.existingSecret -}}
zipkin: tls.autoGenerated
    When enabling auto-generated TLS certificates, all existing secret fields must be empty.
    Please disable auto-generated TLS certificates (--set tls.autoGenerated.enabled=false) or
    remove the existing secret fields.
{{- end -}}
{{- if and (ne .Values.tls.autoGenerated.engine "helm") (ne .Values.tls.autoGenerated.engine "cert-manager") -}}
zipkin: tls.autoGenerated.engine
    Invalid mechanism to generate the TLS certificates selected. Valid values are "helm" and
    "cert-manager". Please set a valid one (--set tls.autoGenerated.engine="xxx")
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Validate values of zipkin - storage is properly configured */}}
{{- define "zipkin.validateValues.storage" -}}
{{- $allowedValues := list "cassandra3" "mem" "other" -}}
{{- if not (has .Values.storageType $allowedValues) -}}
dremio: dist-storage
    Allowed values for `storageType` are {{ join "," $allowedValues }}.
{{- end -}}
{{- end -}}
