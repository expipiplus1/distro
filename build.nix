# Filling the deps taken from Torch's install script
#   https://raw.githubusercontent.com/torch/ezinstall/master/install-deps

{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
} :

let
in

stdenv.mkDerivation {
  name = "torch";
  src = ./.;

  buildInputs = with pkgs;
    [cmake curl readline ncurses gnuplot nodejs unzip nodePackages.npm
     libjpeg libpng imagemagick fftw sox zeromq3 qt4 pythonPackages.ipython
     czmq openblas bash which nvidia_cg_toolkit
    ];

  buildCommand = ''
    . $stdenv/setup
    mkdir -pv $out
    cp -r $src .
    chown -R `whoami` */
    chmod -R +w */
    cd */
    ls -lh
    bash ./install.sh
  '';
}

