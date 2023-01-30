{
  self,
  home-manager,
  #impermanence,
  nixos-hardware,
  nixpkgs,
  ragenix,
  templates,
  ...
}: let
  inherit (nixpkgs) lib;

  nixRegistry = {
    nix.registry = {
      nixpkgs.flake = nixpkgs;
      p.flake = nixpkgs;
      pkgs.flake = nixpkgs;
      templates.flake = templates;
    };
  };

  genConfiguration = hostName: {hostPlatform, ...}:
    lib.nixosSystem {
      modules = [
        (../hosts + "/${hostName}")
		# By default, set networking.hostName to the hostName
		{ networking.hostName = lib.mkDefault hostName; }
        # Use correct pkgs definition
        {
          nixpkgs.pkgs = self.pkgs.${hostPlatform};
          # FIXME: This shouldn't be needed, but is for some reason
          nixpkgs.hostPlatform = hostPlatform;
        }
        nixRegistry
        home-manager.nixosModules.home-manager
        #impermanence.nixosModules.impermanence
        ragenix.nixosModules.age
      ];
      specialArgs = {
        #impermanence = impermanence.nixosModules;
        nixos-hardware = nixos-hardware.nixosModules;
      };
    };
in
  lib.mapAttrs genConfiguration (self.hosts.nixos or {})
