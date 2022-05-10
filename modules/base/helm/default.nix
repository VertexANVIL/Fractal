{ config, lib, ... }:
{
    options = with lib; {
        helm = {
            charts = mkOption {
                type = types.listOf (types.submodule {
                    options = {
                        name = mkOption {
                            type = types.str;
                            description = "The name of the chart";
                        };

                        version = mkOption {
                            type = types.str;
                            description = "The version of the chart";
                        };

                        source = mkOption {
                            type = types.str;
                            description = "The repository of the chart";
                        };
                    };
                });
                default = {};
                description = "Helm charts";
            };
        };
    };
}
