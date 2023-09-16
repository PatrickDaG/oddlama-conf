{
  lib,
  pkgs,
  nixosConfig,
  ...
}: {
  imports =
    [
      ./discord.nix
      ./firefox.nix
      ./kitty.nix
      ./signal.nix
      ./theme.nix
      ./thunderbird.nix
      # XXX: disabled for the time being because gaming under nvidia+wayland has too many bugs
      # XXX: retest this in the future. Problems were flickering under gles, black screens and refresh issues under vulkan, black wine windows.
      # ./sway.nix
      ./i3.nix
    ]
    ++ lib.optionals nixosConfig.graphical.gaming.enable [
      ./games/bottles.nix
      ./games/minecraft.nix
    ];

  home = {
    packages = with pkgs; [
      appimage-run
      chromium
      feh
      pinentry # For yubikey
      sirula
      gamescope
      thunderbird
      xdg-utils
      xdragon
      yt-dlp
      zathura
    ];

    # TODO accounts.concats accounts.calendar
    # TODO test different pinentrys (pinentry gtk?)
    # TODO agenix rekey edit secret should create temp files with same extension
    # TODO mod+f1-4 for left monitor?
    # TODO autostart signal, firefox (both windows), etc.
    # TODO agenix rekey caches in /tmp which is removed each reboot and could be improved
    # TODO entering devshell takes some time after reboot
    # TODO emoji in firefox are wrong
    # TODO screenshot selection/all and copy clipboard
    # TODO screenshot selection/all and save
    # TODO screenshot selection and scan qr and copy clipboard
    # TODO screenshot selection and ocr and copy clipboard
    # TODO sway config
    # TODO sway shortcuts
    # TODO enable nodeadkeys
    # TODO kitty terminfo missing with ssh root@localhost
    # TODO nvim coloscheme missing on reboot.... what state is missing?
    # TODO VP9 hardware video decoding blocklisted
    # TODO gpg switch to sk
    # TODO some font icons not showing neovim

    shellAliases = {
      p = "cd ~/projects";
      zf = "zathura --fork"; # XXX: do i need this or can i just xdg-open?
    };

    persistence."/persist".directories = [
      "projects"
    ];
  };

  xdg.mimeApps.enable = true;
}
