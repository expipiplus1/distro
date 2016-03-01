
{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
} :

let
  trace = builtins.trace;


  inherit (pkgs) lib stdenv callPackage writeText readline makeWrapper
    ncurses cmake;

  luapkgs = rec {


    luajit = with pkgs;
      stdenv.mkDerivation rec {
        name    = "luajit-${version}";
        version = "2.1.0-beta1";
        luaversion = "5.1";

        src = fetchurl {
          url    = "http://luajit.org/download/LuaJIT-${version}.tar.gz";
          sha256 = "06170d38387c59d1292001a166e7f5524f5c5deafa8705a49a46fa42905668dd";
        };

        enableParallelBuilding = true;

        patchPhase = ''
          substituteInPlace Makefile \
            --replace /usr/local $out

          substituteInPlace src/Makefile --replace gcc cc
        '' + stdenv.lib.optionalString (stdenv.cc.libc != null)
        ''
          substituteInPlace Makefile \
            --replace ldconfig ${stdenv.cc.libc}/sbin/ldconfig
        '';

        configurePhase = false;
        buildFlags     = [ "amalg" ]; # Build highly optimized version
        installPhase   = ''
          make install INSTALL_INC=$out/include PREFIX=$out
          ln -s $out/bin/luajit* $out/bin/luajit
        '';

        meta = with stdenv.lib; {
          description = "high-performance JIT compiler for Lua 5.1";
          homepage    = http://luajit.org;
          license     = licenses.mit;
          platforms   = platforms.linux ++ platforms.darwin;
          maintainers = [ maintainers.thoughtpolice ];
        };
      };

    buildLuaPackage_ =
      callPackage
        <nixpkgs/pkgs/development/lua-modules/generic>
        ( luajit // { inherit stdenv; } );

    buildLuaPackage = a : buildLuaPackage_ (a//{
      name = "torch-${a.name}";
    });

    luarocks =
      callPackage
        <nixpkgs/pkgs/development/tools/misc/luarocks>
        { lua = luajit; };

    buildLuaRocks = { rockspec ? "", luadeps ? [] , buildInputs ? []
                    , preBuild ? "" , postInstall ? "" , ... }@args :
      let

        luadeps_ = luadeps ++ (lib.concatMap (d : if d ? luadeps then d.luadeps else []) luadeps);

        mkcfg = trace (lib.length luadeps_) ''
          export LUAROCKS_CONFIG=config.lua
          cat >config.lua <<EOF
            rocks_trees = {
                 { name = [[system]], root = [[${luarocks}]] }
               ${lib.concatImapStrings (i : dep :  ", { name = [[dep${toString i}]], root = [[${dep}]] }") luadeps_}
            };

            variables = {
              LUA_BINDIR = "$out/bin";
              LUA_INCDIR = "$out/include";
              LUA_LIBDIR = "$out/lib/lua/${luajit.luaversion}";
            };
          EOF
        '';
      in
      stdenv.mkDerivation (args // {
        buildInputs = buildInputs ++ [ makeWrapper luajit ];
        phases = [ "unpackPhase" "patchPhase" "buildPhase"];
        inherit preBuild postInstall;


        buildPhase = ''
          eval "$preBuild"
          ${mkcfg}
          eval "`${luarocks}/bin/luarocks --deps-mode=all --tree=$out path`"
          ${luarocks}/bin/luarocks make --deps-mode=all --tree=$out ${rockspec}

          for p in $out/bin/*; do
            wrapProgram $p \
              --set LD_LIBRARY_PATH "${readline}/lib" \
              --set PATH "$PATH" \
              --set LUA_PATH "'$LUA_PATH;$out/share/lua/${luajit.luaversion}/?.lua;$out/share/lua/${luajit.luaversion}/?/init.lua'" \
              --set LUA_CPATH "'$LUA_CPATH;$out/lib/lua/${luajit.luaversion}/?.so;$out/lib/lua/${luajit.luaversion}/?/init.so'"
          done

          eval "$postInstall"
        '';
      });

    lua-cjson = buildLuaPackage {
      name = "lua-cjson";
      src = ./extra/lua-cjson;
    };

    luafilesystem = buildLuaRocks {
      name = "filesystem";
      src = ./extra/luafilesystem;
      luadeps = [lua-cjson];
      rockspec = "rockspecs/luafilesystem-1.6.3-1.rockspec";
    };

    penlight = buildLuaRocks {
      name = "penlight";
      src = ./extra/penlight;
      luadeps = [luafilesystem];
    };

    luaffifb = buildLuaRocks {
      name = "luaffifb";
      src = extra/luaffifb;
    };

    sundown = buildLuaRocks rec {
      name = "sundown";
      src = pkg/sundown;
      rockspec = "rocks/${name}-scm-1.rockspec";
    };

    cwrap = buildLuaRocks rec {
      name = "cwrap";
      src = pkg/cwrap;
      rockspec = "rocks/${name}-scm-1.rockspec";
    };

    paths = buildLuaRocks rec {
      name = "paths";
      src = pkg/paths;
      buildInputs = [cmake];
      rockspec = "rocks/${name}-scm-1.rockspec";
    };

    torch = buildLuaRocks rec {
      name = "torch";
      src = ./pkg/torch;
      luadeps = [ paths cwrap ];
      buildInputs = [ pkgs.cmake ];
      rockspec = "rocks/${name}-scm-1.rockspec";
      preBuild = ''
        export LUA_PATH="$src/?.lua;$LUA_PATH"
      '';
    };

    dok = buildLuaRocks rec {
      name = "dok";
      src = ./pkg/dok;
      luadeps = [sundown];
      rockspec = "rocks/${name}-scm-1.rockspec";
    };

    trepl = buildLuaRocks rec {
      name = "trepl";
      luadeps = [torch penlight];
      buildInputs = [ readline ncurses ];
      src = ./exe/trepl;
    };

    sys = buildLuaRocks rec {
      name = "sys";
      luadeps = [torch];
      buildInputs = [pkgs.readline pkgs.cmake];
      src = ./pkg/sys;
      rockspec = "sys-1.1-0.rockspec";
      preBuild = ''
        export Torch_DIR=${torch}/share/cmake/torch
      '';
    };
  };

in

luapkgs

