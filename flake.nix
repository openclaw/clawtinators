{
  description = "CLAWDINATOR infra + Nix modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-clawdbot.url = "github:clawdbot/nix-clawdbot"; # latest upstream
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, nix-clawdbot, agenix }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: lib.genAttrs systems (system: f system);
      clawdbotOverlay = nix-clawdbot.overlays.default;
      clawdbotShebangFix = final: prev:
        let
          removeScript = final.writeShellScript "remove-package-manager-field.sh" ''
            exec ${final.bash}/bin/bash ${nix-clawdbot}/nix/scripts/remove-package-manager-field.sh "$@"
          '';
          promoteScript = final.writeShellScript "promote-pnpm-integrity.sh" ''
            exec ${final.bash}/bin/bash ${nix-clawdbot}/nix/scripts/promote-pnpm-integrity.sh "$@"
          '';
          nodeGypWrapper = final.writeShellScript "node-gyp-wrapper.sh" ''
            if [ -n "$REAL_NODE_GYP" ]; then
              exec "$REAL_NODE_GYP" "$@"
            fi
            exec node-gyp "$@"
          '';
        in {
          clawdbot-gateway = prev.clawdbot-gateway.overrideAttrs (old: {
            env = (old.env or {}) // {
              PNPM_DEPS = old.pnpmDeps;
              REMOVE_PACKAGE_MANAGER_FIELD_SH = removeScript;
              PROMOTE_PNPM_INTEGRITY_SH = promoteScript;
              NODE_GYP_WRAPPER_SH = nodeGypWrapper;
            };
            postPatch = ''
              if [ -f package.json ]; then
                ${removeScript} package.json
              fi
            '';
            preBuild = ''
              export HOME="$(mktemp -d)"
              store_path="$(mktemp -d)"

              fetcherVersion=$(cat "$PNPM_DEPS/.fetcher-version" 2>/dev/null || echo 1)
              if [ "$fetcherVersion" -ge 3 ]; then
                tar --zstd -xf "$PNPM_DEPS/pnpm-store.tar.zst" -C "$store_path"
              else
                cp -Tr "$PNPM_DEPS" "$store_path"
              fi

              chmod -R +w "$store_path"

              # pnpm --ignore-scripts marks tarball deps as "not built" and offline install
              # later refuses to use them; if a dep doesn't require build, promote it.
              "${promoteScript}" "$store_path"

              pnpm config set store-dir "$store_path"
              pnpm config set package-import-method clone-or-copy
              pnpm config set manage-package-manager-versions false

              export REAL_NODE_GYP="$(command -v node-gyp)"
              wrapper_dir="$(mktemp -d)"
              install -Dm755 "$NODE_GYP_WRAPPER_SH" "$wrapper_dir/node-gyp"
              export PATH="$wrapper_dir:$PATH"
            '';
          });
        };
    in
    {
      nixosModules.clawdinator = import ./nix/modules/clawdinator.nix;
      nixosModules.default = self.nixosModules.clawdinator;

      overlays.clawdbot = clawdbotOverlay;
      overlays.clawdbotShebangFix = clawdbotShebangFix;
      overlays.default = lib.composeExtensions clawdbotOverlay clawdbotShebangFix;

      nixosConfigurations.clawdinator-1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ ... }: { nixpkgs.overlays = [ self.overlays.default ]; })
          agenix.nixosModules.default
          ./nix/hosts/clawdinator-1.nix
        ];
      };

      nixosConfigurations.clawdinator-1-image = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ ... }: { nixpkgs.overlays = [ self.overlays.default ]; })
          agenix.nixosModules.default
          ./nix/hosts/clawdinator-1-image.nix
        ];
      };
    };
}
