# Online Tictactoe using Ocsigen

This is an online Tictactoe game implemented using ocsigen.
Try it [online](https://j3s.fr/blibli/).

## Usage

The app can be built and run using:

```
make test
```

The app will accept browsers at `http://localhost:8080/`.

## Project structure

This is derived from the `client-server.basic` template with some changes.

The Dune build is self-contained (no need to run an other command first) and
the Makefile is greatly simplified. The installation rules and the generation
of the Ocsigen configuration are removed as they were premature.

Project structure:

- blibli.eliom
  This is the entry point module defining the various services.
  Dependency between services is done using dependency-injection, this allows
  to define each service in a different module.

- services/
  This library contains the services and modules shared between the client and
  server.

- blibli.debug.conf
  The ocsigen configuration used when running the app locally.

- static/
  Statically served files. They will be copied into the `var/www` directory.

- dune
  The project is entirely built using Dune.
  The app is built using `dune build @blibli`.

- Makefile
  Contains the extra step needed to run the app locally with `make test`.

- flake.nix
  Package the app using Nix and [opam-nix](https://github.com/tweag/opam-nix).
  Can be removed if not used.
