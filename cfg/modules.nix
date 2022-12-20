{inputs, cell}: let
    inherit (inputs.nixpkgs.lib) attrValues flatten filter kube mapAttrsToList evalModules;
    inherit (inputs.cells.ext) hooks;

in {
    base = {config, ...}: {
        options = {
            inherit (cell.options) cluster resources;
            # default deployment of packages into the cluster's service namespace
            packages = cell.options.packages config.cluster.namespaces.services.name;
        };
        config = {
            # create namespaces
            resources = let
              resource = ns: {
                apiVersion = "v1";
                kind = "Namespace";
                metadata =
                  {inherit (ns) name;}
                  // (
                    optionalAttrs (ns.labels != {})
                    {inherit (ns) labels;}
                  );
              };
            in (
               map
               (ns:
                  (hooks.transformer config { path = ["layers" "10-prelude"];})
                  (resource ns)
               )
               (filter (ns: ns.create) (attrValues config.cluster.namespaces))
            );

            # execute the service packages
            # resources = flatten (map (m: let
            #     package = m.package { inherit config lib; };  
            #     resources = package.resources (m.config // { inherit (m) namespace; });
            # in kube.defaultNamespaces m.namespace resources) config.packages);
        };
    };
    helm = { options = { inherit (cell.options) helm; }; };

    component = component: {config, ...}: {
        freeformType = lib.types.anything;
        config = component;
        options = {
            inherit (cell.options) metadata;
            module = cell.options.module config.metadata.title;
        };
    };
}
