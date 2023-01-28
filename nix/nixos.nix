{
  self,
  home-manager,
  impermanence,
  nixos-hardware,
  nixpkgs,
  ragenix,
  templates,
  ...
}: let
  inherit (nixpkgs) lib;
  hosts = (import ./hosts.nix).nixos;

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
        # Set hostName to same value as key in nixosConfigurations
        {networking.hostName = hostName;}
        # Use correct pkgs definition
        {
          nixpkgs.pkgs = self.pkgs.${hostPlatform};
          # FIXME: This shouldn't be needed, but is for some reason
          nixpkgs.hostPlatform = hostPlatform;
        }
        nixRegistry
        home-manager.nixosModules.home-manager
        impermanence.nixosModules.impermanence
        ragenix.nixosModules.age
      ];
      specialArgs = {
        impermanence = impermanence.nixosModules;
        nixos-hardware = nixos-hardware.nixosModules;
      };
    };
in
  lib.mapAttrs genConfiguration hosts
