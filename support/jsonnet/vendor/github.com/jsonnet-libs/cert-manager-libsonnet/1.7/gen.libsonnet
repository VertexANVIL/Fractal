{
  local d = (import 'doc-util/main.libsonnet'),
  '#':: d.pkg(name='cert_manager', url='github.com/jsonnet-libs/cert-manager-libsonnet/1.7/main.libsonnet', help=''),
  acme:: (import '_gen/acme/main.libsonnet'),
  nogroup:: (import '_gen/nogroup/main.libsonnet'),
}
