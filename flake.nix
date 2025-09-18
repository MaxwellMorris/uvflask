{
  description = "Flask Hello World with uv2nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, pyproject-nix, uv2nix, pyproject-build-systems, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
      editableOverlay = workspace.mkEditablePyprojectOverlay { root = "$REPO_ROOT"; };

      pythonSets = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.python3;
        in
        (pkgs.callPackage pyproject-nix.build.packages { inherit python; })
          .overrideScope (lib.composeManyExtensions [
            pyproject-build-systems.overlays.wheel
            overlay
          ])
      );

    in {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pythonSet = pythonSets.${system}.overrideScope editableOverlay;
          virtualenv = pythonSet.mkVirtualEnv "flask-dev-env" workspace.deps.all;
        in {
          default = pkgs.mkShell {
            packages = [ virtualenv pkgs.uv ];
            env = {
              UV_NO_SYNC = "1";
              UV_PYTHON = pythonSet.python.interpreter;
              UV_PYTHON_DOWNLOADS = "never";
            };
            shellHook = ''
              unset PYTHONPATH
              export REPO_ROOT=$(git rev-parse --show-toplevel)
              . ${virtualenv}/bin/activate
            '';
          };
        }
      );

      packages = forAllSystems (system: {
        default = pythonSets.${system}.mkVirtualEnv "flask-env" workspace.deps.default;
      });

      nixosModules.uvflask = { config, pkgs, ... }: {
        systemd.services.uvflask = {
          description = "Flask app uv flask";
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            ExecStart = "${self.packages.${pkgs.system}.default}/bin/uvflask";
            Restart = "always";
            User = "uvflask";
          };
        };
        users.users.uvflask = {
          isSystemUser = true;
          description = "User for running uvflask service";
          group = "uvflask";
        };
        users.groups.uvflask = {};

        networking.firewall.allowedTCPPorts = [ 5000 ];
      };



    darwinModules.uvflask = { config, lib, pkgs, self, ... }:

    with lib;

    let
      cfg = config.services.uvflask;
    in
    {
      options.services.uvflask = {
        enable = mkEnableOption (mdDoc "Flask uvflask service");

        package = mkOption {
          type = types.package;
          default = self.packages.${pkgs.system}.default;
          defaultText = literalExpression "self.packages.${pkgs.system}.default";
          description = mdDoc "The package that provides the uvflask binary.";
        };

        user = mkOption {
          type = types.str;
          default = "nobody";
          description = mdDoc "User that runs uvflask on Darwin";
        };
      };

      config = mkIf cfg.enable {
        # Make uvflask available in PATH
        environment.systemPackages = [ cfg.package ];

        launchd.daemons.uvflask = {
          script = ''
            mkdir -p /Users/${cfg.user}/.local/share/uvflask
            exec ${cfg.package}/bin/uvflask
          '';
          serviceConfig = {
            KeepAlive = true;
            RunAtLoad = true;
            WorkingDirectory = "/Users/${cfg.user}/.local/share/uvflask";
            StandardOutPath = "/tmp/uvflask.log";
            StandardErrorPath = "/tmp/uvflask-error.log";
          };
        };
      };
    };



    };

}
