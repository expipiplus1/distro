{pkgs ? import <nixpkgs> {}} :
pkgs.callPackage <nixpkgs/pkgs/applications/science/machine-learning/torch/torch-distro.nix> {
    lua = pkgs.luajit;
    src = ./.;
}

