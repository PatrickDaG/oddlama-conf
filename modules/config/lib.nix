{
  extraLib,
  inputs,
  lib,
  ...
}: {
  # IP address math library
  # https://gist.github.com/duairc/5c9bb3c922e5d501a1edb9e7b3b845ba
  # Plus some extensions by us
  lib = let
    libWithNet = (import "${inputs.lib-net}/net.nix" {inherit lib;}).lib;
  in
    lib.recursiveUpdate libWithNet {
      net = {
        cidr = rec {
          # host :: (ip | mac | integer) -> cidr -> ip
          #
          # Wrapper that extends the original host function to
          # check whether the argument `n` is in-range for the given cidr.
          #
          # Examples:
          #
          # > net.cidr.host 255 "192.168.1.0/24"
          # "192.168.1.255"
          # > net.cidr.host (256) "192.168.1.0/24"
          # <fails with an error message>
          # > net.cidr.host (-1) "192.168.1.0/24"
          # "192.168.1.255"
          # > net.cidr.host (-256) "192.168.1.0/24"
          # "192.168.1.0"
          # > net.cidr.host (-257) "192.168.1.0/24"
          # <fails with an error message>
          host = i: n: let
            cap = libWithNet.net.cidr.capacity n;
          in
            assert lib.assertMsg (i >= (-cap) && i < cap) "The host ${toString i} lies outside of ${n}";
              libWithNet.net.cidr.host i n;
          # hostCidr :: (ip | mac | integer) -> cidr -> cidr
          #
          # Returns the nth host in the given cidr range (like cidr.host)
          # but as a cidr that retains the original prefix length.
          #
          # Examples:
          #
          # > net.cidr.hostCidr 2 "192.168.1.0/24"
          # "192.168.1.2/24"
          hostCidr = n: x: "${libWithNet.net.cidr.host n x}/${toString (libWithNet.net.cidr.length x)}";
          # ip :: (cidr | ip) -> ip
          #
          # Returns just the ip part of the cidr.
          #
          # Examples:
          #
          # > net.cidr.ip "192.168.1.100/24"
          # "192.168.1.100"
          # > net.cidr.ip "192.168.1.100"
          # "192.168.1.100"
          ip = x: lib.head (lib.splitString "/" x);
          # canonicalize :: cidr -> cidr
          #
          # Replaces the ip of the cidr with the canonical network address
          # (first contained address in range)
          #
          # Examples:
          #
          # > net.cidr.canonicalize "192.168.1.100/24"
          # "192.168.1.0/24"
          canonicalize = x: libWithNet.net.cidr.make (libWithNet.net.cidr.length x) (ip x);
          # mergev4 :: [cidrv4 | ipv4] -> (cidrv4 | null)
          #
          # Returns the smallest cidr network that includes all given networks.
          # If no cidr mask is given, /32 is assumed.
          #
          # Examples:
          #
          # > net.cidr.mergev4 ["192.168.1.1/24" "192.168.6.1/32"]
          # "192.168.0.0/21"
          mergev4 = addrs_: let
            # Append /32 if necessary
            addrs = map (x:
              if lib.hasInfix "/" x
              then x
              else "${x}/32")
            addrs_;
            # The smallest occurring length is the first we need to start checking, since
            # any greater cidr length represents a smaller address range which
            # wouldn't contain all of the original addresses.
            startLength = lib.foldl' lib.min 32 (map libWithNet.net.cidr.length addrs);
            possibleLengths = lib.reverseList (lib.range 0 startLength);
            # The first ip address will be "expanded" in cidr length until it covers all other
            # used addresses.
            firstIp = ip (lib.head addrs);
            # Return the first (i.e. greatest length -> smallest prefix) cidr length
            # in the list that covers all used addresses
            bestLength = lib.head (lib.filter
              # All given addresses must be contained by the generated address.
              (len:
                lib.all
                (x:
                  libWithNet.net.cidr.contains
                  (ip x)
                  (libWithNet.net.cidr.make len firstIp))
                addrs)
              possibleLengths);
          in
            assert lib.assertMsg (!lib.any (lib.hasInfix ":") addrs) "mergev4 cannot operate on ipv6 addresses";
              if addrs == []
              then null
              else libWithNet.net.cidr.make bestLength firstIp;
          # mergev6 :: [cidrv6 | ipv6] -> (cidrv6 | null)
          #
          # Returns the smallest cidr network that includes all given networks.
          # If no cidr mask is given, /128 is assumed.
          #
          # Examples:
          #
          # > net.cidr.mergev6 ["fd00:dead:cafe::/64" "fd00:fd12:3456:7890::/56"]
          # "fd00:c000::/18"
          mergev6 = addrs_: let
            # Append /128 if necessary
            addrs = map (x:
              if lib.hasInfix "/" x
              then x
              else "${x}/128")
            addrs_;
            # The smallest occurring length is the first we need to start checking, since
            # any greater cidr length represents a smaller address range which
            # wouldn't contain all of the original addresses.
            startLength = lib.foldl' lib.min 128 (map libWithNet.net.cidr.length addrs);
            possibleLengths = lib.reverseList (lib.range 0 startLength);
            # The first ip address will be "expanded" in cidr length until it covers all other
            # used addresses.
            firstIp = ip (lib.head addrs);
            # Return the first (i.e. greatest length -> smallest prefix) cidr length
            # in the list that covers all used addresses
            bestLength = lib.head (lib.filter
              # All given addresses must be contained by the generated address.
              (len:
                lib.all
                (x:
                  libWithNet.net.cidr.contains
                  (ip x)
                  (libWithNet.net.cidr.make len firstIp))
                addrs)
              possibleLengths);
          in
            assert lib.assertMsg (lib.all (lib.hasInfix ":") addrs) "mergev6 cannot operate on ipv4 addresses";
              if addrs == []
              then null
              else libWithNet.net.cidr.make bestLength firstIp;
          # merge :: [cidr] -> { cidrv4 = (cidrv4 | null); cidrv6 = (cidrv4 | null); }
          #
          # Returns the smallest cidr network that includes all given networks,
          # but yields two separate result for all given ipv4 and ipv6 addresses.
          # Equivalent to calling mergev4 and mergev6 on a partition individually.
          merge = addrs: let
            v4_and_v6 = lib.partition (lib.hasInfix ":") addrs;
          in {
            cidrv4 = mergev4 v4_and_v6.wrong;
            cidrv6 = mergev6 v4_and_v6.right;
          };
          # assignIps :: cidr -> [int | ip] -> [string] -> [ip]
          #
          # Assigns a semi-stable ip address from the given cidr network to each hostname.
          # The algorithm is based on hashing (abusing sha256) with linear probing.
          # The order of hosts doesn't matter. No ip (or offset) from the reserved list
          # will be assigned. The network address and broadcast address will always be reserved
          # automatically.
          #
          # Examples:
          #
          # > net.cidr.assignIps "192.168.100.1/24" [] ["a" "b" "c"]
          # { a = "192.168.100.202"; b = "192.168.100.74"; c = "192.168.100.226"; }
          #
          # > net.cidr.assignIps "192.168.100.1/24" [] ["a" "b" "c" "a-new-elem"]
          # { a = "192.168.100.202"; a-new-elem = "192.168.100.88"; b = "192.168.100.74"; c = "192.168.100.226"; }
          #
          # > net.cidr.assignIps "192.168.100.1/24" [202 "192.168.100.74"] ["a" "b" "c"]
          # { a = "192.168.100.203"; b = "192.168.100.75"; c = "192.168.100.226"; }
          assignIps = net: reserved: hosts: let
            cidrSize = libWithNet.net.cidr.size net;
            capacity = libWithNet.net.cidr.capacity net;
            # The base address of the network. Used to convert ip-based reservations to offsets
            baseAddr = host 0 net;
            # Reserve some values for the network, host and broadcast address.
            # The network and broadcast address should never be used, and we
            # want to reserve the host address for the host. We also convert
            # any ips to offsets here.
            init = lib.unique (
              [0 (capacity - 1)]
              ++ lib.flip map reserved (x:
                if builtins.typeOf x == "int"
                then x
                else -(libWithNet.net.ip.diff baseAddr x))
            );
            nHosts = builtins.length hosts;
            nInit = builtins.length init;
            # Pre-sort all hosts, to ensure ordering invariance
            sortedHosts =
              lib.warnIf
              ((nInit + nHosts) > 0.3 * capacity)
              "assignIps: hash stability may be degraded since utilization is >30%"
              (builtins.sort builtins.lessThan hosts);
            # Generates a hash (i.e. offset value) for a given hostname
            hashElem = x:
              builtins.bitAnd (capacity - 1)
              (extraLib.hexToDec (builtins.substring 0 16 (builtins.hashString "sha256" x)));
            # Do linear probing. Returns the first unused value at or after the given value.
            probe = avoid: value:
              if lib.elem value avoid
              # TODO lib.mod
              # Poor man's modulo, because nix has no modulo. Luckily we operate on a residue
              # class of x modulo 2^n, so we can use bitAnd instead.
              then probe avoid (builtins.bitAnd (capacity - 1) (value + 1))
              else value;
            # Hash a new element and avoid assigning any existing values.
            assignOne = {
              assigned,
              used,
            }: x: let
              value = probe used (hashElem x);
            in {
              assigned =
                assigned
                // {
                  ${x} = host value net;
                };
              used = [value] ++ used;
            };
          in
            assert lib.assertMsg (cidrSize >= 2 && cidrSize <= 62)
            "assignIps: cidrSize=${toString cidrSize} is not in [2, 62].";
            assert lib.assertMsg (nHosts <= capacity - nInit)
            "assignIps: number of hosts (${toString nHosts}) must be <= capacity (${toString capacity}) - reserved (${toString nInit})";
            # Assign an ip in the subnet to each element, in order
              (lib.foldl' assignOne {
                  assigned = {};
                  used = init;
                }
                sortedHosts)
              .assigned;
        };
        ip = rec {
          # Checks whether the given address (with or without cidr notation) is an ipv4 address.
          isv4 = x: !isv6 x;
          # Checks whether the given address (with or without cidr notation) is an ipv6 address.
          isv6 = lib.hasInfix ":";
        };
        mac = {
          # Adds offset to the given base address and ensures the result is in
          # a locally administered range by replacing the second nibble with a 2.
          addPrivate = base: offset: let
            added = libWithNet.net.mac.add base offset;
            pre = lib.substring 0 1 added;
            suf = lib.substring 2 (-1) added;
          in "${pre}2${suf}";
          # assignMacs :: mac (base) -> int (size) -> [int | mac] (reserved) -> [string] (hosts) -> [mac]
          #
          # Assigns a semi-stable MAC address starting in [base, base + 2^size) to each hostname.
          # The algorithm is based on hashing (abusing sha256) with linear probing.
          # The order of hosts doesn't matter. No mac (or offset) from the reserved list
          # will be assigned.
          #
          # Examples:
          #
          # > net.mac.assignMacs "11:22:33:00:00:00" 24 [] ["a" "b" "c"]
          # { a = "11:22:33:1b:bd:ca"; b = "11:22:33:39:59:4a"; c = "11:22:33:50:7a:e2"; }
          #
          # > net.mac.assignMacs "11:22:33:00:00:00" 24 [] ["a" "b" "c" "a-new-elem"]
          # { a = "11:22:33:1b:bd:ca"; a-new-elem = "11:22:33:d6:5d:58"; b = "11:22:33:39:59:4a"; c = "11:22:33:50:7a:e2"; }
          #
          # > net.mac.assignMacs "11:22:33:00:00:00" 24 ["11:22:33:1b:bd:ca"] ["a" "b" "c"]
          # { a = "11:22:33:1b:bd:cb"; b = "11:22:33:39:59:4a"; c = "11:22:33:50:7a:e2"; }
          assignMacs = base: size: reserved: hosts: let
            capacity = extraLib.pow 2 size;
            baseAsInt = libWithNet.net.mac.diff base "00:00:00:00:00:00";
            init = lib.unique (
              lib.flip map reserved (x:
                if builtins.typeOf x == "int"
                then x
                else libWithNet.net.mac.diff x base)
            );
            nHosts = builtins.length hosts;
            nInit = builtins.length init;
            # Pre-sort all hosts, to ensure ordering invariance
            sortedHosts =
              lib.warnIf
              ((nInit + nHosts) > 0.3 * capacity)
              "assignMacs: hash stability may be degraded since utilization is >30%"
              (builtins.sort builtins.lessThan hosts);
            # Generates a hash (i.e. offset value) for a given hostname
            hashElem = x:
              builtins.bitAnd (capacity - 1)
              (extraLib.hexToDec (builtins.substring 0 16 (builtins.hashString "sha256" x)));
            # Do linear probing. Returns the first unused value at or after the given value.
            probe = avoid: value:
              if lib.elem value avoid
              # TODO lib.mod
              # Poor man's modulo, because nix has no modulo. Luckily we operate on a residue
              # class of x modulo 2^n, so we can use bitAnd instead.
              then probe avoid (builtins.bitAnd (capacity - 1) (value + 1))
              else value;
            # Hash a new element and avoid assigning any existing values.
            assignOne = {
              assigned,
              used,
            }: x: let
              value = probe used (hashElem x);
            in {
              assigned =
                assigned
                // {
                  ${x} = libWithNet.net.mac.add value base;
                };
              used = [value] ++ used;
            };
          in
            assert lib.assertMsg (size >= 2 && size <= 62)
            "assignMacs: size=${toString size} is not in [2, 62].";
            assert lib.assertMsg (builtins.bitAnd (capacity - 1) baseAsInt == 0)
            "assignMacs: the size=${toString size} least significant bits of the base mac address must be 0.";
            assert lib.assertMsg (nHosts <= capacity - nInit)
            "assignMacs: number of hosts (${toString nHosts}) must be <= capacity (${toString capacity}) - reserved (${toString nInit})";
            # Assign an ip in the subnet to each element, in order
              (lib.foldl' assignOne {
                  assigned = {};
                  used = init;
                }
                sortedHosts)
              .assigned;
        };
      };
    };
}