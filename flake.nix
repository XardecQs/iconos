{
  description = "Colección de iconos y cursores personalizados para NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      forEachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      themeDirs = builtins.attrNames (
        nixpkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./src)
      );

      resolveDeps =
        pkgs: name:
        {
          "definitivo" = [
            pkgs.papirus-icon-theme
            pkgs.adwaita-icon-theme
            pkgs.hicolor-icon-theme
          ];
          "macos-tahoe-cursor" = [ pkgs.hicolor-icon-theme ];
        }
        .${name} or [ ];

      mkThemePkg =
        pkgs: name:
        pkgs.stdenvNoCC.mkDerivation {
          pname = name;
          version = "1.0";
          src = ./src + "/${name}";

          nativeBuildInputs = [
            pkgs.gtk3
            pkgs.gtk4
          ];
          propagatedBuildInputs = resolveDeps pkgs name;

          dontDropIconThemeCache = true;
          dontWrapQtApps = true;
          dontPatchShebangs = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/icons/${name}
            cp -r . $out/share/icons/${name}

            # Aseguramos que index.theme exista y tenga permisos correctos
            chmod 644 $out/share/icons/${name}/index.theme 2>/dev/null || true

            # Actualizamos caché (GTK3 y GTK4)
            ${pkgs.gtk3}/bin/gtk-update-icon-cache --force --include-image-data $out/share/icons/${name}
            ${pkgs.gtk4}/bin/gtk4-update-icon-cache --force $out/share/icons/${name} 2>/dev/null || true

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Tema de iconos ${name}";
            license = licenses.unfree;
            platforms = platforms.all;
          };
        };

      mkSystemPackages =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          themePkgs = builtins.listToAttrs (
            map (name: {
              inherit name;
              value = mkThemePkg pkgs name;
            }) themeDirs
          );
        in
        themePkgs
        // {
          default = pkgs.symlinkJoin {
            name = "icon-collection";
            paths = builtins.attrValues themePkgs;
            meta = with pkgs.lib; {
              description = "Colección completa de iconos y cursores";
              license = licenses.unfree;
              platforms = platforms.all;
            };
          };
        };
    in
    {
      packages = forEachSystem mkSystemPackages;

      nixosModules.default =
        { pkgs, ... }:
        {
          environment.systemPackages = builtins.attrValues (mkSystemPackages pkgs.system);
          gtk.iconCache.enable = true;
        };
    };
}
