{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    # Store layout configs in an XDG directory and not in a .direnv local directory
    stdlib = ''
      : ''${XDG_CACHE_HOME:=$HOME/.cache}
      declare -A direnv_layout_dirs
      direnv_layout_dir() {
          echo "''${direnv_layout_dirs[$PWD]:=$(
              echo -n "$XDG_CACHE_HOME"/direnv/layouts/
              echo -n "$PWD" | shasum | cut -d ' ' -f 1
          )}"
      }
    '';
  };

  home.persistence."/state".directories = [
    ".local/share/direnv"
  ];
}
