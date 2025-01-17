self: super: let
  inherit
    (self.lib)
    escapeShellArg
    concatMapStrings
    flip
    ;

  make-custom-caddy = {
    plugins,
    vendorHash,
  }: let
    caddyPatchMain =
      flip concatMapStrings plugins
      ({name, ...}: "sed -i '/plug in Caddy modules here/a \\\\t_ \"${name}\"' cmd/caddy/main.go\n");
    caddyPatchGoGet =
      flip concatMapStrings plugins
      ({
        name,
        version,
      }: "go get ${escapeShellArg name}@${escapeShellArg version}\n");
  in
    super.caddy.override {
      buildGoModule = args:
        super.buildGoModule (args
          // {
            inherit vendorHash;
            passthru.plugins = plugins;

            overrideModAttrs = _: {
              preBuild = caddyPatchGoGet;
              postInstall = "cp go.mod go.sum $out/";
            };

            postPatch = caddyPatchMain;
            postConfigure = "cp vendor/go.mod vendor/go.sum .";
          });
    };
in {
  # Example usage:
  # caddy.withPackages {
  #   plugins = [
  #     { name = "github.com/greenpau/caddy-security"; version = "v1.1.18"; }
  #   ];
  #   vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  # }
  caddy = super.caddy.overrideAttrs (_: {passthru.withPackages = make-custom-caddy;});
}
