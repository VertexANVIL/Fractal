{
  local d = (import 'doc-util/main.libsonnet'),
  '#':: d.pkg(name='v1beta1', url='', help=''),
  clusterExternalSecret: (import 'clusterExternalSecret.libsonnet'),
  clusterSecretStore: (import 'clusterSecretStore.libsonnet'),
  externalSecret: (import 'externalSecret.libsonnet'),
  secretStore: (import 'secretStore.libsonnet'),
}
