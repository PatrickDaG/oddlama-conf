{
  config,
  lib,
  ...
}: {
  networking.nftables = {
    stopRuleset = lib.mkDefault ''
      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;
          ct state invalid drop
          ct state {established, related} accept

          iifname lo accept
          meta l4proto ipv6-icmp accept
          meta l4proto icmp accept
          tcp dport ${toString (lib.head config.services.openssh.ports)} accept
        }
        chain forward {
          type filter hook forward priority filter; policy drop;
        }
        chain output {
          type filter hook output priority filter; policy accept;
        }
      }
    '';

    firewall = {
      enable = true;

      # TODO mkForce nftables
      zones = lib.mkForce {
        local.localZone = true;
      };

      rules = lib.mkForce {
        icmp = {
          early = true;
          after = ["ct"];
          from = "all";
          to = ["local"];
          extraLines = [
            "ip6 nexthdr icmpv6 icmpv6 type { echo-request, destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept"
            "ip protocol icmp icmp type { echo-request, destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept"
            #"ip6 saddr fe80::/10 ip6 daddr fe80::/10 udp dport 546 accept" # (dhcpv6)
          ];
        };

        ssh = {
          early = true;
          after = ["ct"];
          from = "all";
          to = ["local"];
          allowedTCPPorts = config.services.openssh.ports;
        };

        untrusted-to-local = {
          from = ["untrusted"];
          to = ["local"];

          inherit
            (config.networking.firewall)
            allowedTCPPorts
            allowedUDPPorts
            ;
        };
      };
    };
  };
}
