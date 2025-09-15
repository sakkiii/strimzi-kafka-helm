{{/*
Expand the name of the chart.
*/}}
{{- define "strimzi-kafka.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "strimzi-kafka.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as part of the labels.
*/}}
{{- define "strimzi-kafka.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "strimzi-kafka.labels" -}}
helm.sh/chart: {{ include "strimzi-kafka.chart" . }}
{{ include "strimzi-kafka.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "strimzi-kafka.annotations" -}}
{{- with .Values.global.commonAnnotations }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "strimzi-kafka.selectorLabels" -}}
app.kubernetes.io/name: {{ include "strimzi-kafka.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Merge global and component-specific nodeSelector configurations
Usage: {{ include "strimzi-kafka.nodeSelector" (dict "global" .Values.global.nodeSelector "component" .Values.kafkaCluster.nodePools.0.template.pod.nodeSelector "context" .) }}
*/}}
{{- define "strimzi-kafka.nodeSelector" -}}
{{- $global := .global -}}
{{- $component := .component -}}
{{- $context := .context -}}
{{- $result := dict -}}

{{/* Start with global nodeSelector if it exists */}}
{{- if $global -}}
  {{- $result = deepCopy $global -}}
{{- end -}}

{{/* Merge component-specific nodeSelector, overriding global settings */}}
{{- if $component -}}
  {{- $result = deepCopy (merge $result $component) -}}
{{- end -}}

{{- if $result -}}
nodeSelector:
  {{- tpl (toYaml $result | nindent 2) $context }}
{{- end -}}
{{- end }}

{{/*
Merge global and component-specific affinity configurations, converting nodeSelector to nodeAffinity
Usage: {{ include "strimzi-kafka.affinity" (dict "global" .Values.global.affinity "component" .Values.kafkaCluster.nodePools.0.template.pod.affinity "globalNodeSelector" .Values.global.nodeSelector "componentNodeSelector" .Values.kafkaCluster.nodePools.0.template.pod.nodeSelector "context" .) }}
*/}}
{{- define "strimzi-kafka.affinity" -}}
{{- $global := .global -}}
{{- $component := .component -}}
{{- $globalNodeSelector := .globalNodeSelector -}}
{{- $componentNodeSelector := .componentNodeSelector -}}
{{- $context := .context -}}
{{- $result := dict -}}

{{/* Start with global affinity if it exists */}}
{{- if $global -}}
  {{- $result = deepCopy $global -}}
{{- end -}}

{{/* Convert global nodeSelector to nodeAffinity */}}
{{- if $globalNodeSelector -}}
  {{- $nodeAffinityFromSelector := dict -}}
  {{- $matchExpressions := list -}}
  {{- range $key, $value := $globalNodeSelector -}}
    {{- $matchExpressions = append $matchExpressions (dict "key" $key "operator" "In" "values" (list $value)) -}}
  {{- end -}}
  {{- if $matchExpressions -}}
    {{- $nodeAffinityFromSelector = dict "requiredDuringSchedulingIgnoredDuringExecution" (dict "nodeSelectorTerms" (list (dict "matchExpressions" $matchExpressions))) -}}
    {{- if not $result.nodeAffinity -}}
      {{- $_ := set $result "nodeAffinity" $nodeAffinityFromSelector -}}
    {{- else -}}
      {{/* Merge with existing nodeAffinity */}}
      {{- if $result.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution -}}
        {{- $existingTerms := $result.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms | default list -}}
        {{- $newTerms := $nodeAffinityFromSelector.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms -}}
        {{- $mergedTerms := concat $existingTerms $newTerms -}}
        {{- $_ := set $result.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution "nodeSelectorTerms" $mergedTerms -}}
      {{- else -}}
        {{- $_ := set $result.nodeAffinity "requiredDuringSchedulingIgnoredDuringExecution" $nodeAffinityFromSelector.requiredDuringSchedulingIgnoredDuringExecution -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Convert component nodeSelector to nodeAffinity */}}
{{- if $componentNodeSelector -}}
  {{- $nodeAffinityFromSelector := dict -}}
  {{- $matchExpressions := list -}}
  {{- range $key, $value := $componentNodeSelector -}}
    {{- $matchExpressions = append $matchExpressions (dict "key" $key "operator" "In" "values" (list $value)) -}}
  {{- end -}}
  {{- if $matchExpressions -}}
    {{- $nodeAffinityFromSelector = dict "requiredDuringSchedulingIgnoredDuringExecution" (dict "nodeSelectorTerms" (list (dict "matchExpressions" $matchExpressions))) -}}
    {{- if not $result.nodeAffinity -}}
      {{- $_ := set $result "nodeAffinity" $nodeAffinityFromSelector -}}
    {{- else -}}
      {{/* Merge with existing nodeAffinity */}}
      {{- if $result.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution -}}
        {{- $existingTerms := $result.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms | default list -}}
        {{- $newTerms := $nodeAffinityFromSelector.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms -}}
        {{- $mergedTerms := concat $existingTerms $newTerms -}}
        {{- $_ := set $result.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution "nodeSelectorTerms" $mergedTerms -}}
      {{- else -}}
        {{- $_ := set $result.nodeAffinity "requiredDuringSchedulingIgnoredDuringExecution" $nodeAffinityFromSelector.requiredDuringSchedulingIgnoredDuringExecution -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Merge with component-specific affinity if it exists */}}
{{- if $component -}}
  {{- if $component.nodeAffinity -}}
    {{- if not $result.nodeAffinity -}}
      {{- $_ := set $result "nodeAffinity" $component.nodeAffinity -}}
    {{- else -}}
      {{/* Merge nodeAffinity - component overrides global */}}
      {{- $mergedNodeAffinity := dict -}}
      {{- if $component.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution -}}
        {{- $_ := set $mergedNodeAffinity "requiredDuringSchedulingIgnoredDuringExecution" $component.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution -}}
      {{- else if $result.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution -}}
        {{- $_ := set $mergedNodeAffinity "requiredDuringSchedulingIgnoredDuringExecution" $result.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution -}}
      {{- end -}}
      {{- if $component.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution -}}
        {{- $_ := set $mergedNodeAffinity "preferredDuringSchedulingIgnoredDuringExecution" $component.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution -}}
      {{- else if $result.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution -}}
        {{- $_ := set $mergedNodeAffinity "preferredDuringSchedulingIgnoredDuringExecution" $result.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution -}}
      {{- end -}}
      {{- $_ := set $result "nodeAffinity" $mergedNodeAffinity -}}
    {{- end -}}
  {{- end -}}
  {{- if $component.podAffinity -}}
    {{- $_ := set $result "podAffinity" $component.podAffinity -}}
  {{- end -}}
  {{- if $component.podAntiAffinity -}}
    {{- $_ := set $result "podAntiAffinity" $component.podAntiAffinity -}}
  {{- end -}}
{{- end -}}

{{/* Render the final affinity configuration */}}
{{- if or $result.nodeAffinity $result.podAffinity $result.podAntiAffinity -}}
affinity:
  {{- if $result.nodeAffinity }}
  nodeAffinity:
    {{- tpl (toYaml $result.nodeAffinity | nindent 4) $context }}
  {{- end }}
  {{- if $result.podAffinity }}
  podAffinity:
    {{- tpl (toYaml $result.podAffinity | nindent 4) $context }}
  {{- end }}
  {{- if $result.podAntiAffinity }}
  podAntiAffinity:
    {{- tpl (toYaml $result.podAntiAffinity | nindent 4) $context }}
  {{- end }}
{{- end -}}
{{- end }}

{{/*
Merge global and component-specific tolerations configurations
Usage: {{ include "strimzi-kafka.tolerations" (dict "global" .Values.global.tolerations "component" .Values.kafkaCluster.nodePools.0.template.pod.tolerations "context" .) }}
*/}}
{{- define "strimzi-kafka.tolerations" -}}
{{- $global := .global -}}
{{- $component := .component -}}
{{- $context := .context -}}
{{- $result := list -}}

{{/* Start with global tolerations if they exist */}}
{{- if $global -}}
  {{- $result = $global -}}
{{- end -}}

{{/* Override with component-specific tolerations if they exist */}}
{{- if $component -}}
  {{- $result = $component -}}
{{- end -}}

{{/* Render the final tolerations configuration */}}
{{- if $result }}
tolerations:
  {{- tpl (toYaml $result | nindent 2) $context }}
{{- end -}}
{{- end }}

{{/*
Match labels for selector
*/}}
{{- define "strimzi-kafka.matchLabels" -}}
app.kubernetes.io/name: {{ include "strimzi-kafka.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate ingress class name - prefer new ingress.className over legacy ingressClass
*/}}
{{- define "strimzi-kafka.ingressClassName" -}}
{{- $external := .Values.kafkaCluster.listeners.external -}}
{{- if $external.ingress.className -}}
  {{- $external.ingress.className -}}
{{- else if $external.ingressClass -}}
  {{- $external.ingressClass -}}
{{- else -}}
  nginx
{{- end -}}
{{- end }}

{{/*
Generate ingress host - prefer new ingress.host over legacy bootstrapHost
*/}}
{{- define "strimzi-kafka.ingressHost" -}}
{{- $external := .Values.kafkaCluster.listeners.external -}}
{{- if $external.ingress.host -}}
  {{- tpl $external.ingress.host . -}}
{{- else if $external.bootstrapHost -}}
  {{- tpl $external.bootstrapHost . -}}
{{- else -}}
  {{- .Release.Name }}.example.com
{{- end -}}
{{- end }}

{{/*
Generate ingress annotations - prefer new ingress.annotations over legacy bootstrapAnnotations
Only render if annotations are not empty
*/}}
{{- define "strimzi-kafka.ingressAnnotations" -}}
{{- $external := .Values.kafkaCluster.listeners.external -}}
{{- $annotations := dict -}}
{{- if $external.ingress.annotations -}}
  {{- $annotations = $external.ingress.annotations -}}
{{- else if $external.bootstrapAnnotations -}}
  {{- $annotations = $external.bootstrapAnnotations -}}
{{- end -}}
{{- if $annotations -}}
  {{- range $key, $value := $annotations }}
    {{- if $value }}
{{ $key }}: {{ tpl (toString $value) $ | quote }}
    {{- end }}
  {{- end }}
{{- end -}}
{{- end }}

{{/*
Generate TLS secret name - auto-generate if not specified
*/}}
{{- define "strimzi-kafka.tlsSecretName" -}}
{{- $external := .Values.kafkaCluster.listeners.external -}}
{{- if and $external.ingress.tls.enabled $external.ingress.tls.secretName -}}
  {{- tpl $external.ingress.tls.secretName . -}}
{{- else if $external.ingress.tls.enabled -}}
  {{- .Release.Name }}-kafka-tls
{{- end -}}
{{- end }}

{{/*
Generate broker ingress host pattern - uses broker-{broker}-{parent.host} format
*/}}
{{- define "strimzi-kafka.brokerIngressHostPattern" -}}
{{- $brokers := .Values.kafkaCluster.listeners.external.brokers -}}
{{- $parentHost := include "strimzi-kafka.ingressHost" . -}}
{{- if $brokers.hostPattern -}}
  {{- $brokers.hostPattern -}}
{{- else -}}
  broker-{broker}-{{ $parentHost }}
{{- end -}}
{{- end }}

{{/*
Generate broker ingress annotations - inherits from parent ingress annotations
Replaces {broker} placeholder and adds broker-specific external-dns hostname
*/}}
{{- define "strimzi-kafka.brokerIngressAnnotations" -}}
{{- $external := .Values.kafkaCluster.listeners.external -}}
{{- $brokers := $external.brokers -}}
{{- $parentAnnotations := dict -}}

{{/* Get parent annotations */}}
{{- if $external.ingress.annotations -}}
  {{- $parentAnnotations = $external.ingress.annotations -}}
{{- else if $external.bootstrapAnnotations -}}
  {{- $parentAnnotations = $external.bootstrapAnnotations -}}
{{- end -}}

{{/* Use parent annotations or fall back to legacy broker annotations */}}
{{- $annotations := $parentAnnotations -}}
{{- if and (not $parentAnnotations) $brokers.annotations -}}
  {{- $annotations = $brokers.annotations -}}
{{- end -}}

{{- if $annotations -}}
  {{- range $key, $value := $annotations }}
    {{- if $value }}
      {{- if eq $key "external-dns.alpha.kubernetes.io/hostname" }}
{{ $key }}: "broker-{broker}-{{ include "strimzi-kafka.ingressHost" $ }}"
      {{- else }}
{{ $key }}: {{ tpl (toString $value) $ | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "strimzi-kafka.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "strimzi-kafka.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Global values for clusterName - defaults to Release.Name if not specified
*/}}
{{- define "strimzi-kafka.clusterName" -}}
{{- if .Values.kafkaCluster.name }}
{{- .Values.kafkaCluster.name }}
{{- else }}
{{- .Release.Name }}
{{- end }}
{{- end }}

{{/*
Global values for namespace - defaults to Release.Namespace if not specified
*/}}
{{- define "strimzi-kafka.namespace" -}}
{{- if .Values.kafkaCluster.namespace }}
{{- .Values.kafkaCluster.namespace }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Generate node pool name with cluster prefix
*/}}
{{- define "strimzi-kafka.nodePoolName" -}}
{{- $clusterName := include "strimzi-kafka.clusterName" . -}}
{{- printf "%s-%s" $clusterName .name }}
{{- end }}

{{/*
Generate secret name with cluster prefix
*/}}
{{- define "strimzi-kafka.secretName" -}}
{{- $clusterName := include "strimzi-kafka.clusterName" . -}}
{{- printf "%s-%s" $clusterName .secretName }}
{{- end }}

{{/*
Generate template name with cluster prefix
*/}}
{{- define "strimzi-kafka.templateName" -}}
{{- $clusterName := include "strimzi-kafka.clusterName" . -}}
{{- printf "%s-%s" $clusterName .templateName }}
{{- end }}

{{/*
Generate image registry - component specific or global default
Usage: {{ include "strimzi-kafka.imageRegistry" (dict "component" .Values.kafkaCluster.image "global" .Values.global "context" .) }}
*/}}
{{- define "strimzi-kafka.imageRegistry" -}}
{{- $component := .component -}}
{{- $global := .global -}}
{{- if and $component $component.registry -}}
  {{- $component.registry -}}
{{- else if $global.defaultImageRegistry -}}
  {{- $global.defaultImageRegistry -}}
{{- else -}}
  quay.io
{{- end -}}
{{- end }}

{{/*
Generate image repository - component specific or global default
Usage: {{ include "strimzi-kafka.imageRepository" (dict "component" .Values.kafkaCluster.image "global" .Values.global "context" .) }}
*/}}
{{- define "strimzi-kafka.imageRepository" -}}
{{- $component := .component -}}
{{- $global := .global -}}
{{- if and $component $component.repository -}}
  {{- $component.repository -}}
{{- else if $global.defaultImageRepository -}}
  {{- $global.defaultImageRepository -}}
{{- else -}}
  strimzi
{{- end -}}
{{- end }}

{{/*
Generate image tag - component specific or global default
Usage: {{ include "strimzi-kafka.imageTag" (dict "component" .Values.kafkaCluster.image "global" .Values.global "context" .) }}
*/}}
{{- define "strimzi-kafka.imageTag" -}}
{{- $component := .component -}}
{{- $global := .global -}}
{{- if and $component $component.tag -}}
  {{- $component.tag -}}
{{- else if $global.defaultImageTag -}}
  {{- $global.defaultImageTag -}}
{{- else -}}
  0.47.0-kafka-3.9.0
{{- end -}}
{{- end }}

{{/*
Generate full image name
Usage: {{ include "strimzi-kafka.image" (dict "component" .Values.kafkaCluster.image "imageName" "kafka" "global" .Values.global "context" .) }}
*/}}
{{- define "strimzi-kafka.image" -}}
{{- $component := .component -}}
{{- $imageName := .imageName -}}
{{- $global := .global -}}
{{- $context := .context -}}
{{- $registry := include "strimzi-kafka.imageRegistry" (dict "component" $component "global" $global "context" $context) -}}
{{- $repository := include "strimzi-kafka.imageRepository" (dict "component" $component "global" $global "context" $context) -}}
{{- $tag := include "strimzi-kafka.imageTag" (dict "component" $component "global" $global "context" $context) -}}
{{- if and $component $component.name -}}
  {{- printf "%s/%s/%s:%s" $registry $repository $component.name $tag -}}
{{- else if $imageName -}}
  {{- printf "%s/%s/%s:%s" $registry $repository $imageName $tag -}}
{{- else -}}
  {{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- end -}}
{{- end }}

{{/*
Generate image pull policy - component specific or global default
Usage: {{ include "strimzi-kafka.imagePullPolicy" (dict "component" .Values.kafkaCluster.image "global" .Values.global "context" .) }}
*/}}
{{- define "strimzi-kafka.imagePullPolicy" -}}
{{- $component := .component -}}
{{- $global := .global -}}
{{- if and $component $component.pullPolicy -}}
  {{- $component.pullPolicy -}}
{{- else if $global.imagePullPolicy -}}
  {{- $global.imagePullPolicy -}}
{{- else -}}
  IfNotPresent
{{- end -}}
{{- end }}

{{/*
Generate image pull secrets - merge global and component specific
Usage: {{ include "strimzi-kafka.imagePullSecrets" (dict "component" .Values.kafkaCluster.image "global" .Values.global "context" .) }}
*/}}
{{- define "strimzi-kafka.imagePullSecrets" -}}
{{- $component := .component -}}
{{- $global := .global -}}
{{- $context := .context -}}
{{- $secrets := list -}}

{{/* Add global pull secrets */}}
{{- if $global.imagePullSecrets -}}
  {{- $secrets = concat $secrets $global.imagePullSecrets -}}
{{- end -}}

{{/* Add component-specific pull secrets */}}
{{- if and $component $component.pullSecrets -}}
  {{- $secrets = concat $secrets $component.pullSecrets -}}
{{- end -}}

{{/* Render if we have any secrets */}}
{{- if $secrets -}}
imagePullSecrets:
  {{- range $secrets }}
  - {{ . | toYaml | nindent 4 }}
  {{- end }}
{{- end -}}
{{- end }}

{{/*
Generate broker hosts dynamically based on replicas or HPA maxReplicas
*/}}
{{- define "strimzi-kafka.brokerHosts" -}}
{{- $hostPattern := .Values.kafkaCluster.listeners.external.brokers.hostPattern }}
{{- $hpaEnabled := .Values.hpa.enabled }}
{{- $replicas := .Values.kafkaCluster.replicas }}
{{- if $hpaEnabled }}
  {{- $maxReplicas := .Values.hpa.maxReplicas }}
  {{- range $i := until (int $maxReplicas) }}
- broker: {{ $i }}
  host: {{ $hostPattern | replace "{broker}" (toString $i) }}
  {{- end }}
{{- else }}
  {{- range $i := until (int $replicas) }}
- broker: {{ $i }}
  host: {{ $hostPattern | replace "{broker}" (toString $i) }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Generate Kafka version for compatibility
*/}}
{{- define "strimzi-kafka.kafkaVersion" -}}
{{- .Values.kafkaCluster.version | default "3.9.0" }}
{{- end }}

{{/*
Generate storage class if specified
*/}}
{{- define "strimzi-kafka.storageClass" -}}
{{- if .storageClass }}
class: {{ .storageClass }}
{{- end }}
{{- end }}


{{/*
Generate listener configuration based on type
*/}}
{{- define "strimzi-kafka.listenerConfig" -}}
{{- if eq .type "ingress" }}
class: {{ .ingressClass }}
bootstrap:
  host: {{ .bootstrapHost }}
  annotations:
    {{- toYaml .bootstrapAnnotations | nindent 4 }}
{{- else if eq .type "loadbalancer" }}
{{- if .loadBalancerSourceRanges }}
loadBalancerSourceRanges:
  {{- toYaml .loadBalancerSourceRanges | nindent 2 }}
{{- end }}
{{- if .annotations }}
annotations:
  {{- toYaml .annotations | nindent 2 }}
{{- end }}
{{- else if eq .type "nodeport" }}
{{- if .nodePort }}
nodePort: {{ .nodePort }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate metrics configuration
*/}}
{{- define "strimzi-kafka.metricsConfig" -}}
{{- if .enabled }}
metricsConfig:
  type: {{ .type }}
  valueFrom:
    configMapKeyRef:
      name: {{ .configMapName }}
      key: {{ .configMapKey }}
{{- end }}
{{- end }}

{{/*
Generate resource configuration
*/}}
{{- define "strimzi-kafka.resources" -}}
resources:
  requests:
    memory: {{ .requests.memory }}
    cpu: {{ .requests.cpu }}
  limits:
    memory: {{ .limits.memory }}
    cpu: {{ .limits.cpu }}
{{- end }}

{{/*
Generate JVM options
*/}}
{{- define "strimzi-kafka.jvmOptions" -}}
jvmOptions:
  -Xms: {{ .xms | quote }}
  -Xmx: {{ .xmx | quote }}
{{- end }}

{{/*
Generate storage configuration
*/}}
{{- define "strimzi-kafka.storage" -}}
{{- if .enabled }}
storage:
  type: {{ .type }}
  volumes:
    {{- range .volumes }}
    - id: {{ .id }}
      type: {{ .type }}
      size: {{ .size }}
      deleteClaim: {{ .deleteClaim }}
      kraftMetadata: {{ .kraftMetadata }}
      {{- if .storageClass }}
      class: {{ .storageClass }}
      {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Generate authentication configuration
*/}}
{{- define "strimzi-kafka.authentication" -}}
authentication:
  type: {{ .type }}
  {{- if eq .type "scram-sha-512" }}
  {{- if .username }}
  username: {{ .username }}
  {{- end }}
  {{- if .passwordSecret }}
  passwordSecret:
    secretName: {{ .passwordSecret.secretName }}
    password: {{ .passwordSecret.password }}
  {{- end }}
  {{- end }}
{{- end }}

{{/*
Validate required values
*/}}
{{- define "strimzi-kafka.validateValues" -}}
{{- if not .Values.kafkaCluster.name }}
{{- fail "kafkaCluster.name is required" }}
{{- end }}
{{- if not .Values.kafkaCluster.version }}
{{- fail "kafkaCluster.version is required" }}
{{- end }}
{{- if lt (.Values.kafkaCluster.replicas | int) 1 }}
{{- fail "kafkaCluster.replicas must be at least 1" }}
{{- end }}
{{- if and .Values.hpa.enabled (lt (.Values.hpa.minReplicas | int) 1) }}
{{- fail "hpa.minReplicas must be at least 1 when HPA is enabled" }}
{{- end }}
{{- if and .Values.hpa.enabled (lt (.Values.hpa.maxReplicas | int) (.Values.hpa.minReplicas | int)) }}
{{- fail "hpa.maxReplicas must be greater than or equal to hpa.minReplicas" }}
{{- end }}
{{- end }}

{{/*
Generate external listener brokers based on configuration
*/}}
{{- define "strimzi-kafka.externalBrokers" -}}
{{- if .Values.kafkaCluster.listeners.external.brokers.generateDynamic }}
{{- $maxBrokers := .Values.kafkaCluster.listeners.external.brokers.maxBrokers | default 10 }}
{{- $hostPattern := .Values.kafkaCluster.listeners.external.brokers.hostPattern }}
{{- $annotations := .Values.kafkaCluster.listeners.external.brokers.annotations }}
{{- $hpaEnabled := .Values.hpa.enabled }}
{{- $replicas := .Values.kafkaCluster.replicas }}
{{- if $hpaEnabled }}
  {{- $maxReplicas := .Values.hpa.maxReplicas }}
  {{- range $i := until (int $maxReplicas) }}
- broker: {{ $i }}
  host: {{ $hostPattern | replace "{broker}" (toString $i) }}
  annotations:
    {{- range $key, $value := $annotations }}
    {{ $key }}: {{ $value | replace "{broker}" (toString $i) | quote }}
    {{- end }}
  {{- end }}
{{- else }}
  {{- range $i := until (int $replicas) }}
- broker: {{ $i }}
  host: {{ $hostPattern | replace "{broker}" (toString $i) }}
  annotations:
    {{- range $key, $value := $annotations }}
    {{ $key }}: {{ $value | replace "{broker}" (toString $i) | quote }}
    {{- end }}
  {{- end }}
{{- end }}
{{- else }}
{{- range .Values.kafkaCluster.listeners.external.brokers }}
- broker: {{ .broker }}
  host: {{ .host }}
  {{- if .annotations }}
  annotations:
    {{- toYaml .annotations | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate Kafka configuration with large message support
*/}}
{{- define "strimzi-kafka.kafkaConfig" -}}
{{- range $key, $value := .Values.kafkaCluster.config }}
{{ $key }}: {{ $value }}
{{- end }}
{{- end }}