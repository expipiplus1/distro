
{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
} :

let
  trace = builtins.trace;

  np = <nixpkgs>;

  inherit (pkgs) stdenv callPackage;

  luapkgs = rec {

    buildLuaPackage_ = (callPackage "${np}/pkgs/development/lua-modules/generic" ( pkgs.luajit // { inherit stdenv; } ));

    buildLuaPackage = a : buildLuaPackage_ (a//{
      name = "torch-${a.name}";
    });

    luafilesystem = buildLuaPackage {
      name = "filesystem";
      src = ./extra/luafilesystem;
    };

  };

in

luapkgs

