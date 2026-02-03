{
  description = "CLAWDINATOR infra + Nix modules";

  inputs = {
    nix-openclaw.url = "github:openclaw/nix-openclaw"; # latest upstream
    nixpkgs.follows = "nix-openclaw/nixpkgs";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, nix-openclaw, agenix }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: lib.genAttrs systems (system: f system);
      clawbotOverlay = nix-openclaw.overlays.default;
    in
    {
      nixosModules.clawdinator = import ./nix/modules/clawdinator.nix;
      nixosModules.default = self.nixosModules.clawdinator;

      overlays.clawbot = clawbotOverlay;
      overlays.default = clawbotOverlay;

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
          gateway =
            if pkgs ? openclaw-gateway
            then pkgs.openclaw-gateway
            else pkgs.openclaw;
          systemPackages =
            if system == "x86_64-linux" then {
              clawdinator-system = self.nixosConfigurations.clawdinator-1.config.system.build.toplevel;
              clawdinator-image-system = self.nixosConfigurations.clawdinator-1-image.config.system.build.toplevel;
            } else {};
        in {
          openclaw-gateway = gateway;
          default = gateway;
        } // systemPackages);

      nixosConfigurations.clawdinator-1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ ... }: { nixpkgs.overlays = [ self.overlays.default ]; })
          agenix.nixosModules.default
          ./nix/hosts/clawdinator-1.nix
        ];
      };

      nixosConfigurations.clawdinator-2 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ ... }: { nixpkgs.overlays = [ self.overlays.default ]; })
          agenix.nixosModules.default
          ./nix/hosts/clawdinator-2.nix
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
