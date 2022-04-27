{
  local d = (import 'doc-util/main.libsonnet'),
  '#':: d.pkg(name='v1', url='', help=''),
  certificate: (import 'certificate.libsonnet'),
  certificateRequest: (import 'certificateRequest.libsonnet'),
  clusterIssuer: (import 'clusterIssuer.libsonnet'),
  issuer: (import 'issuer.libsonnet'),
}
