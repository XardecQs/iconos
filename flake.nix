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
          nativeBuildInputs = [ pkgs.gtk3 ];
          propagatedBuildInputs = resolveDeps pkgs name;
          dontDropIconThemeCache = true;
          dontWrapQtApps = true;
          installPhase = ''
            mkdir -p $out/share/icons
            cp -r . $out/share/icons/${name}
            if [ -f $out/share/icons/${name}/index.theme ]; then
              ${pkgs.gtk3}/bin/gtk-update-icon-cache \
                --include-image-data $out/share/icons/${name}
            fi
          '';
          meta = with pkgs.lib; {
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
        let
          themePkgs = builtins.listToAttrs (
            map (name: {
              inherit name;
              value = mkThemePkg (import nixpkgs {
                inherit (pkgs.stdenv.hostPlatform) system;
                config.allowUnfree = true;
              }) name;
            }) themeDirs
          );
        in
        {
          environment.systemPackages = builtins.attrValues themePkgs;
        };
    };
}
