{
  local d = (import 'doc-util/main.libsonnet'),
  '#':: d.pkg(name='v1', url='', help=''),
  alertmanager: (import 'alertmanager.libsonnet'),
  podMonitor: (import 'podMonitor.libsonnet'),
  probe: (import 'probe.libsonnet'),
  prometheus: (import 'prometheus.libsonnet'),
  prometheusRule: (import 'prometheusRule.libsonnet'),
  serviceMonitor: (import 'serviceMonitor.libsonnet'),
  thanosRuler: (import 'thanosRuler.libsonnet'),
}
