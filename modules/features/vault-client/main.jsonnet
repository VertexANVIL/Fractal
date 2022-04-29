local c = import "lib/common.libsonnet";
local i = std.extVar("inputs");

{
    local helmRelease = c.flux.helm.v2beta1.helmRelease,

    _values:: {
        global: {
            tlsDisable: false
        },

        injector: {
            externalVaultAddr: "https://vault.arctarus.net",
            authPath: "auth/k8s-%s" % i.cluster.name,
        },

        server: {
            enabled: false,
            authDelegator: {
                enabled: false
            }
        }
    },

    issuer: c.kk.clusterIssuer.new("vault")
        + c.kk.clusterIssuer.spec.vault.withCaBundle("LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUdoVENDQkcyZ0F3SUJBZ0lVSW04eG9ycTNxNVNGZjRjVjJJTGxXOUo0TEZNd0RRWUpLb1pJaHZjTkFRRUwKQlFBd2dkQXhDekFKQmdOVkJBWVRBa2RDTVJZd0ZBWURWUVFJREExVGRHbHliR2x1WjNOb2FYSmxNUkV3RHdZRApWUVFIREFoVGRHbHliR2x1WnpFM01Ca0dBMVVFQ1F3U1EyOXliaUJGZUdOb1lXNW5aU0JTYjJGa01Cb0dBMVVFCkNRd1RUWFZ1YVdOcGNHRnNJRUoxYVd4a2FXNW5jekVQTUEwR0ExVUVFUXdHUmtzNE1raFZNUmt3RndZRFZRUUsKREJCQmNtTjBZWEoxY3lCTWFXMXBkR1ZrTVJZd0ZBWURWUVFMREExVFpXTjFjbWwwZVNCRVpYQjBNUmt3RndZRApWUVFEREJCQmNtTjBZWEoxY3lCU2IyOTBJRU5CTUNBWERUSXhNVEV5TmpFek5Ua3pNbG9ZRHpJeE1qRXhNVEF5Ck1UTTFPVE15V2pDQjBERUxNQWtHQTFVRUJoTUNSMEl4RmpBVUJnTlZCQWdNRFZOMGFYSnNhVzVuYzJocGNtVXgKRVRBUEJnTlZCQWNNQ0ZOMGFYSnNhVzVuTVRjd0dRWURWUVFKREJKRGIzSnVJRVY0WTJoaGJtZGxJRkp2WVdRdwpHZ1lEVlFRSkRCTk5kVzVwWTJsd1lXd2dRblZwYkdScGJtZHpNUTh3RFFZRFZRUVJEQVpHU3pneVNGVXhHVEFYCkJnTlZCQW9NRUVGeVkzUmhjblZ6SUV4cGJXbDBaV1F4RmpBVUJnTlZCQXNNRFZObFkzVnlhWFI1SUVSbGNIUXgKR1RBWEJnTlZCQU1NRUVGeVkzUmhjblZ6SUZKdmIzUWdRMEV3Z2dJaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQwpEd0F3Z2dJS0FvSUNBUUN5cmYxMkNoRExrdHU0SW5UTlVzU0tTWUF6TXA4QWVMd1R0dlBGbXJLSWxCdjVZVWFCCm5HZ05GSUQ4amxOUDdoczdKc1FFN2VHRDU4SmNFcjB3TlhOOHZvbnFvc2xidzJGYndkQVc5RlNySml0ajYxSEMKYnh0eHd5U3JIaWo3ank0NlBCT3pNOHcrbEJGM3lybXo5WkdIdWljSHNFZWZlV1IwVFRxaVU4QU1zaDZjejZPcgpleGsvNzNkT1VXTUFYeG9IbFFISlRlbUZpTE56UkxidFVYVVloZmFGaUlFRDgzNldrRWhVaHdsZkY0S2ZmbUNsCnVOQUhyS09RdXdzYzFPbXJjYnV3N2oxVXFWUVd0NUtJZEJJVkwvcmhsZ1Nyd1VVRUJYanhyL2R1ODJMclorRVQKWXFaUjB3UHZGbGtTTTBxZzRobWNRMUtUYjlyUXJRSERvMWQ2MXdsbHUvdGkxSCsrS0ZodnZWS3JNMmZscnhESwpCTHJWNjNSTk5DWHVWaHAxZ3llUlJDVys1WkJpTk5lZkd3SUdVMnE1NTdxUUNSQnJrN1h1eEk5QkJpeWlvRW9rCmNqeXBRQ2dHbktFZk9SZERoSUlkV3J0UkZRWXpiWlZOSFpDbk1OcDMxaXFCV3pUVEFuRUpNd2N0T0h5VlZwOUgKU0ZnOXd4Sno5dlVPVTNjM2o3aHYybFNZRGkzRnIycmRjS2UvYWRxVEhqUmNrdVd6aG8rUk4rY3NqRDBzMmZvQwo3MVV1eXRFejdNbXFHSDNmVjE4QXRhWkNVUVdIV2JjUHFEd0dFUWNhT214NTNlRFFhTUxDMnArUU94OHRYTXQwCmYrZW5XcGRsMVhQOHFpbE1paGFBVkpYY3lxT3VKMXJaY1RqcjRQNnRsd05BYXJDcGowc05uTVFiaFFJREFRQUIKbzFNd1VUQWRCZ05WSFE0RUZnUVVuandvTHNicC96SWxOdEhZNDhhNm02NjZaN2d3SHdZRFZSMGpCQmd3Rm9BVQpuandvTHNicC96SWxOdEhZNDhhNm02NjZaN2d3RHdZRFZSMFRBUUgvQkFVd0F3RUIvekFOQmdrcWhraUc5dzBCCkFRc0ZBQU9DQWdFQXNUQVlyeTE2MVFrNEJWMVpSRmlqbUd5Rkh0a2k5N0plU1g0Qm0zWmFMdnpueGRKaVV1SFIKT1VHQ3lwM3pkeTltRFVNVDY5MERjdWtPVG9RRE9DdWRFcmcvbExYUUM4eDVQUlFQSmtjTm9wRVE2ZXBnVmprcwpWT0k1c3hPazdXaGFjN3VmL1BaZW82SUNJK2UrSUN3QzVFUURiaUVQS01seVlyVlZXR3lLYkxlSVYxYURVUVRZClhJSlJQZHJlOVlnQU1oZ0FVdlI5N0RRR3dCYldMSDBaWnR6NUNwcjdDZGlUV0ltZXUyRzg1L3lzd3FZYi9aUDMKenpqaTVuQzlRSnJPbmYrQUNhSXFsQjFKTWNWOStHcXdGeHM0bTJnU1hLYVQ2RGZtMVlPRmwwNEZROFVNUGFNaQoxMU5SQzk2aWNXK2gwNjhXQktSbXlYVlpjOTVVUjNiTGhUbGVTSUFTdzRHZXVPUGdiYjV5TXNheEpIVC9OWVl0ClkxQ295blpnWXBkS3hpWGpVOVc5M2R6UzNqRWw4Z2NQV1N2UkYvN04zcEtnVkJxMUU2cGl4a1JhMlcrcm9QSHIKaUlyVWxBZlhCUC9IN0NyZzVNSXJjVUFUWWtnUHFZUGZGTUFXU2dLS0FzYzQ5OElZY21KUFdMVnc1WXVDQmplOQpHUm1vakZrOFo3ZHZjSjlmWERoQXlmakpWNWFId0FYV0tCOTJzTE96Z1lvdHN1UE01dmkvOUJheE9qd1h6NzVJCldZMFhmSjJ0R1JrOFdHSFFFeHV4RSsyZFRLWlphUHVmdVB2R0xocmxwR1NTcUd5RVJnWmxlMnkvTk5xbVBrbU4KSERPcUtMMEdEVk9TNVh3cDBwdmZKVHJRRFhha2ZIaS9BYnpXZHY2TUVNdENtMnMwL1RQamZQRT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=")
        + c.kk.clusterIssuer.spec.vault.withPath("pki/sign/k8s-%s-issuer" % i.cluster.name)
        + c.kk.clusterIssuer.spec.vault.withServer("https://vault.arctarus.net")
        + c.kk.clusterIssuer.spec.vault.auth.kubernetes.withMountPath("/v1/auth/k8s-%s" % i.cluster.name)
        + c.kk.clusterIssuer.spec.vault.auth.kubernetes.withRole("k8s-%s-issuer" % i.cluster.name)
        + c.kk.clusterIssuer.spec.vault.auth.kubernetes.secretRef.withKey("token")
        + c.kk.clusterIssuer.spec.vault.auth.kubernetes.secretRef.withName("vault-issuer-token"),

    issuerToken: c.kk.secret.new("vault-issuer-token", {}, type="kubernetes.io/service-account-token")
        + c.kk.secret.metadata.withAnnotations({
            "kubernetes.io/service-account.name": "cert-manager-issuer"
        }),
    
    metadata: c.kk.configMap.new("vault-metadata", {
        address: "https://vault.arctarus.net",
        "vault.ca": importstr "vault.pem",
    }),

    release: helmRelease.new(i.component.name)
        + helmRelease.spec.withValues($._values)
        + helmRelease.spec.chart.spec.withChart("vault")
        + helmRelease.spec.chart.spec.withVersion(i.component.version)
        + helmRelease.spec.chart.spec.sourceRef.withKind("HelmRepository")
        + helmRelease.spec.chart.spec.sourceRef.withName("hashicorp")
        + helmRelease.spec.chart.spec.sourceRef.withNamespace("flux-system")
        + helmRelease.spec.install.remediation.withRemediateLastFailure(true)
        + helmRelease.spec.upgrade.remediation.withRemediateLastFailure(true)
}
