{
  self,
  colmena,
  home-manager,
  #impermanence,
  nixos-hardware,
  nixpkgs,
  microvm,
  agenix,
  agenix-rekey,
  ...
} @ inputs: let
  inherit
    (nixpkgs.lib)
    optionals
    ;

  extraLib = import ./lib.nix inputs;
in
  nodeName: nodeMeta: {
    inherit (nodeMeta) system;
    pkgs = self.pkgs.${nodeMeta.system};
    specialArgs = {
      inherit (nixpkgs) lib;
      inherit extraLib;
      inherit inputs;
      inherit nodeName;
      inherit nodeMeta;
      inherit (self) nodes;
      secrets = self.secrets.content;
      nodeSecrets = self.secrets.content.nodes.${nodeName};
      nixos-hardware = nixos-hardware.nixosModules;
      #impermanence = impermanence.nixosModules;
    };
    imports =
      [
        (../hosts + "/${nodeName}")
        home-manager.nixosModules.default
        #impermanence.nixosModules.default
        agenix.nixosModules.default
        agenix-rekey.nixosModules.default
      ]
      ++ optionals nodeMeta.microVmHost [
        microvm.nixosModules.host
      ]
      ++ optionals (nodeMeta.type == "microvm") [
        microvm.nixosModules.microvm
      ];
  }