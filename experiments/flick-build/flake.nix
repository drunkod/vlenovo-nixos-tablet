{
  description = "Isolated x86_64-linux Flick package experiment; does not activate NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-rust.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpkgs-rust, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      rustPkgs = nixpkgs-rust.legacyPackages.x86_64-linux;
      rustPlatform = pkgs.makeRustPlatform {
        cargo = rustPkgs.cargo;
        rustc = rustPkgs.rustc;
      };
    in {
      packages.x86_64-linux.flick = pkgs.callPackage ./pkgs/flick {
        inherit rustPlatform;
      };
      packages.x86_64-linux.default = pkgs.callPackage ./pkgs/flick { inherit rustPlatform; };
    };
}
