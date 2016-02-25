# Filling the deps taken from Torch's install script
#   https://raw.githubusercontent.com/torch/ezinstall/master/install-deps

{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
} :

with pkgs;

let

# luajit = import ../luajit/luajit.nix {inherit pkgs;};

in

stdenv.mkDerivation rec {
  name = "torch";
  src = ./.;

  buildInputs = with pkgs;
    [cmake curl readline ncurses gnuplot nodejs unzip nodePackages.npm
     libjpeg libpng imagemagick fftw sox zeromq3 qt4 pythonPackages.ipython
     czmq openblas bash which cudatoolkit libuuid makeWrapper
    ];

  luajit_dir = "./exe/luajit-rocks/luajit-2.1";

  luajit_patchPhase = ''

    substituteInPlace ${luajit_dir}/Makefile \
          --replace /usr/local $out

    substituteInPlace ${luajit_dir}/src/Makefile --replace gcc cc
  '' + stdenv.lib.optionalString (stdenv.cc.libc != null)
  ''
    substituteInPlace ${luajit_dir}/Makefile \
      --replace ldconfig ${stdenv.cc.libc}/sbin/ldconfig
  '';

  buildCommand = ''
    . $stdenv/setup
    mkdir -pv $out
    cp -r $src .
    chown -R `whoami` */
    chmod -R +w */
    cd */

    mkdir -pv $out/home

    ${luajit_patchPhase}

    export HOME=$out/home
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${readline}/lib"
    export CMAKE_LIBRARY_PATH="${openblas}/include:${openblas}/lib:$CMAKE_LIBRARY_PATH"
    export PREFIX=$out
    bash ./install.sh -b

    for p in $out/bin/*; do
      wrapProgram $p \
        --set LD_LIBRARY_PATH "${readline}/lib"
    done

  '';
}

