// https://github.com/immich-app/immich/issues/33173
try {
  const { PrometheusExporter } = await import('@opentelemetry/exporter-prometheus');
  PrometheusExporter.DEFAULT_OPTIONS.host = '0.0.0.0';
} catch (error) {
  console.warn(`otel-prometheus-host preload skipped: ${error}`);
}
