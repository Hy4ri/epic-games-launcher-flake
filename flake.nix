{
  description = "Official native Epic Games Launcher for Linux — Nix flake with multi-arch FHS environment for GE-Proton";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = [
      "x86_64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    overlay = final: _prev: {
      epic-games-launcher-unwrapped = final.callPackage ./package.nix {};
      epic-games-launcher-fhs = final.callPackage ./fhs.nix {
        inherit (final) epic-games-launcher-unwrapped;
      };
      epic-games-launcher = final.epic-games-launcher-fhs;
    };

    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ overlay ];
      });
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      inherit (pkgs)
        epic-games-launcher
        epic-games-launcher-fhs
        epic-games-launcher-unwrapped
        ;
      default = pkgs.epic-games-launcher;
    });

    devShells = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          curl
          coreutils
          jq
          nix
        ];
      };
    });

    overlays.default = overlay;

    nixosModules.default = {
      config,
      lib,
      pkgs,
      ...
    }: let
      cfg = config.programs.epic-games-launcher;
    in {
      options.programs.epic-games-launcher = {
        enable = lib.mkEnableOption "Epic Games Launcher for Linux";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.epic-games-launcher;
          defaultText = lib.literalExpression "pkgs.epic-games-launcher";
          description = "The Epic Games Launcher package to install (defaults to the multi-arch FHS wrapper).";
        };
      };

      config = lib.mkIf cfg.enable {
        nixpkgs.overlays = [ overlay ];
        environment.systemPackages = [ cfg.package ];
        hardware.graphics = {
          enable = lib.mkDefault true;
          enable32Bit = lib.mkDefault true;
        };
      };
    };
  };
}
