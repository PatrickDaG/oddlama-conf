{
  config,
  lib,
  ...
}: {
  imports = [
    ../common/core
    ../common/hardware/hetzner-cloud.nix
    ../common/bios-boot.nix
    ../common/initrd-ssh.nix
    ../common/zfs.nix

    ./fs.nix
    ./net.nix
    ./nginx.nix
  ];

  boot.loader.grub.devices = ["/dev/disk/by-id/${config.repo.secrets.local.disk.main}"];
}