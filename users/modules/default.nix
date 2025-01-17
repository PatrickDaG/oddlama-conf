{...}: {
  imports = [
    ./neovim.nix
    ./secrets.nix
    ./uid.nix

    ./config/htop.nix
    ./config/impermanence.nix
    ./config/manpager
    ./config/neovim.nix
    ./config/shell
    ./config/utils.nix
  ];

  xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
}
