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

      runtimeDeps = with pkgs; [
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

      fhsEnv = pkgs.buildFHSEnv {
        name = "superluminal-fhs";
        targetPkgs = _: runtimeDeps;
        runScript = "bash";
      };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "superluminal";
        version = "1.0.7705.679-alpha";

        inherit src;

        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = runtimeDeps;

        # Superluminal and SuperluminalCmd must stay byte-identical to the signed
        # originals: the capture service rejects connecting clients whose
        # /proc/pid/exe fails .slsig signature verification. They are run through
        # an FHS env wrapper instead of being patched.
        dontAutoPatchelf = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib/superluminal
          cp -r . $out/lib/superluminal/
          runHook postInstall
        '';

        postInstall = ''
          mkdir -p $out/bin
          for exe in Superluminal SuperluminalCmd; do
            {
              echo '#!${pkgs.runtimeShell}'
              echo "export QT_PLUGIN_PATH=$out/lib/superluminal/Qt/plugins"
              echo "exec ${fhsEnv}/bin/superluminal-fhs -c 'exec $out/lib/superluminal/$exe \"\$@\"' $exe \"\$@\""
            } > $out/bin/$exe
            chmod +x $out/bin/$exe
          done
          for exe in SuperluminalCaptureService SuperluminalCrashReporter SuperluminalAutoUpdater; do
            ln -s $out/lib/superluminal/$exe $out/bin/$exe
          done

          install -Dm644 $out/lib/superluminal/Documentation/Superluminal/assets/img/logo.svg \
            $out/share/icons/hicolor/scalable/apps/superluminal.svg

          mkdir -p $out/share/applications
          {
            echo '[Desktop Entry]'
            echo 'Type=Application'
            echo 'Name=Superluminal'
            echo 'Comment=Performance profiler'
            echo 'Exec=Superluminal'
            echo 'Icon=superluminal'
            echo 'Categories=Development;'
          } > $out/share/applications/superluminal.desktop
        '';

        postFixup = ''
          mv $out/lib/superluminal/Superluminal $out/lib/superluminal/SuperluminalCmd "$TMPDIR"
          autoPatchelf --no-recurse $out/lib/superluminal
          addAutoPatchelfSearchPath $out/lib/superluminal
          autoPatchelf $out/lib/superluminal/Qt $out/lib/superluminal/slPlugins
          mv "$TMPDIR"/Superluminal "$TMPDIR"/SuperluminalCmd $out/lib/superluminal/
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
