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

        scope = buildOpamProject {
          resolveArgs = {
            depopts = false;
            env.sys-ocaml-version = "4.14.1";
          };
        } "blibli" ./. { ocaml-system = "*"; };

        dist = scope.blibli.overrideAttrs (_: {
          buildPhase = "dune build @blibli";
          installPhase = ''
            cp -rTL _build/default/dist $out
            echo "$OCAMLPATH" > $out/lib/ocaml_library_path
          '';
        });

        ocsigen_debug_conf = pkgs.writeText "ocsigen.debug.conf" ''
          <ocsigen>
            <server>
              <port>8080</port>
              <logdir>local/var/log/blibli</logdir>
              <datadir>local/var/data/blibli</datadir>
              <charset>utf-8</charset>
              <uploaddir>/tmp</uploaddir>
              <usedefaulthostname/>
              <debugmode/>
              <extension findlib-package="ocsigenserver.ext.accesscontrol"/>
              <extension findlib-package="ocsigenserver.ext.cors"/>
              <commandpipe>local/var/run/blibli-cmd</commandpipe>
              <extension findlib-package="ocsigenserver.ext.staticmod"/>
              <extension findlib-package="ocsipersist.sqlite">
                <database file="local/var/data/blibli/ocsidb"/>
              </extension>
              <extension findlib-package="eliom.server">
                <!-- Ask Eliom to ignore UTM parameters and others: -->
                <ignoredgetparams regexp="utm_[a-z]*|[a-z]*clid|li_fat_id"/>
              </extension>
              <host hostfilter="*">
                <static dir="${dist}/var/www/blibli" />
                <eliommodule module="${dist}/lib/blibli/blibli.cmxs">
                  <app name="blibli" css="${dist}/static/css/blibli.css" />
                  <avatars dir="local/var/www/avatars" />
                </eliommodule>
                <eliom/>
                <if>
                  <header name="origin" regexp="http://localhost:8000"/>
                  <then>
                    <cors max_age="86400"
                      credentials="true"
                      methods="POST,GET,HEAD"
                      exposed_headers="x-eliom-application,x-eliom-location,x-eliom-set-process-cookies,x-eliom-set-cookie-substitutes"/>
                  </then>
                </if>
              </host>
            </server>
          </ocsigen>
        '';

        runserver = pkgs.writeShellScript "blibli-run" ''
          export OCAMLPATH=`cat ${dist}/lib/ocaml_library_path`
          ${scope.ocsigenserver}/bin/ocsigenserver.opt -c "$1"
        '';

        runserver_debug = pkgs.writeShellScript "blibli-run" ''
          ${runserver} ${ocsigen_debug_conf}
        '';

      in {
        packages = { inherit dist runserver runserver_debug; };
        defaultPackage = runserver_debug;
      });
}
