

* Building locally
nix build

* Creating and running a docker image
~docker build -t flake.uv2nix:dev .~

~sudo docker run --rm -p 8080:5000 flake.uv2nix:dev~

Access website via http://localhost:8080.
