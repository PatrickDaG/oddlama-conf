{nodeSecrets, ...}: {
  networking = {
    hostId = "4313abca";
    wireless.iwd.enable = true;
  };

  systemd.network.networks = {
    "10-lan1" = {
      DHCP = "yes";
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.lan1.mac;
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    "10-wlan1" = {
      DHCP = "yes";
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.wlan1.mac;
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 40;
      dhcpV6Config.RouteMetric = 40;
    };
  };

  extra.wireguard.vms.address = ["10.0.0.10/32"];
}
