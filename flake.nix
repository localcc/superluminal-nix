{
  description = "Superluminal Profiler";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    src = {
      url = "https://superluminal.blob.core.windows.net/public-installers/SuperluminalLinux-1.0.7705.679-alpha.tar.gz";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, src, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "superluminal";
        version = "1.0.7705.679-alpha";

        inherit src;

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          makeWrapper
        ];

        buildInputs = with pkgs; [
          stdenv.cc.cc.lib
          glib
          libglvnd
          fontconfig
          freetype
          zlib
          dbus
          elfutils
          gtk3
          libxkbcommon
          libx11
          libxext
          libxcb
          libxcb-util
          libxcb-image
          libxcb-keysyms
          libxcb-render-util
          libxcb-wm
        ];

        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib/superluminal
          cp -r . $out/lib/superluminal/
          runHook postInstall
        '';

        postInstall = ''
          mkdir -p $out/bin
          for exe in Superluminal SuperluminalCmd SuperluminalCaptureService SuperluminalCrashReporter SuperluminalAutoUpdater; do
            makeWrapper $out/lib/superluminal/$exe $out/bin/$exe \
              --set QT_PLUGIN_PATH "$out/lib/superluminal/Qt/plugins"
          done

          install -Dm644 $out/lib/superluminal/Documentation/Superluminal/assets/img/logo.svg \
            $out/share/icons/hicolor/scalable/apps/superluminal.svg

          mkdir -p $out/share/applications
          cat > $out/share/applications/superluminal.desktop <<EOF
          [Desktop Entry]
          Type=Application
          Name=Superluminal
          Comment=Performance profiler
          Exec=Superluminal
          Icon=superluminal
          Categories=Development;
          EOF
        '';
      };
    }
    // {
      nixosModules.default =
        { config, lib, pkgs, ... }:
        let
          cfg = config.programs.superluminal;
        in
        {
          options.programs.superluminal = {
            enable = lib.mkEnableOption "Superluminal profiler";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
              description = "The Superluminal package to use.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];

            systemd.sockets.superluminal-capture = {
              description = "Superluminal Capture Service activation socket";
              wantedBy = [ "sockets.target" ];
              socketConfig = {
                ListenStream = "@SuperluminalCaptureService";
                Accept = "no";
              };
            };

            systemd.services.superluminal-capture = {
              description = "Superluminal Capture Service";
              serviceConfig = {
                ExecStart = "${cfg.package}/bin/SuperluminalCaptureService --service";
                User = "root";
              };
            };
          };
        };
    };
}
