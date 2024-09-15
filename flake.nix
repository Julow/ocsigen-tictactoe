{
  inputs.nixpkgs.url = "nixpkgs/nixos-23.11";
  inputs.opam-repository = {
    url = "github:ocaml/opam-repository";
    flake = false;
  };
  inputs.opam-nix = {
    url = "github:Julow/opam-nix/overlay-ocsigenserver";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.opam-repository.follows = "opam-repository";
  };

  outputs = { self, nixpkgs, opam-nix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (opam-nix.lib.${system}) buildOpamProject;

        pkgs = import nixpkgs { inherit system; };

        scope = buildOpamProject { } "blibli" ./. { };

        dist = scope.blibli.overrideAttrs (_: {
          buildPhase = "dune build @blibli @install";
          installPhase = ''
            mkdir -p $out
            cp -rL _build/install/default/bin _build/default/dist $out
          '';
        });

        runserver_debug = pkgs.writeShellScriptBin "blibli-run" ''
          d=`mktemp -d`
          cp -rTL --no-preserve=mode,ownership ${dist}/dist "$d/local"
          cd "$d"
          exec ${dist}/bin/blibli
        '';

      in {
        packages = { inherit dist runserver_debug; };
        defaultPackage = runserver_debug;
      });
}
