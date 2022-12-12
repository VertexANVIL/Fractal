{lib}: with lib; {
   metadata = {
     title = mkOption {
         type = types.str;
         default = "Component";
         description = "The friendly name of the component";
     };

     labels = mkOption {
         type = types.attrsOf types.str;
         default = {};
         description = "Labels to default to all resources within this component";
     };

     annotations = mkOption {
         type = types.attrsOf types.str;
         default = {};
         description = "Annotations to default to all resources within this component";
     };
   };
   module = title: mkOption {
       type = types.submodule ({ config, ... }: {
           options = {
               options = mkOption {
                   type = types.submodule {
                       freeformType = types.anything;
                       options = { enable = lib.mkEnableOption title; };
                   };
                   description = "Component-level module options";
               };

               config = mkOption {
                   type = types.submodule { freeformType = types.attrsOf types.anything; };
                   description = "Component-level module config";
               };
           };
       });
       description = ''
         Component level module.

         Its options and configuration will be transparently hoisted
         to the top level cluster configuration under the component
         attribute path: <type>.<name> or <type>.<namespace>.<name>
       '';
   };
}
