
{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
} :

let
  trace = builtins.trace;


  inherit (pkgs) lib stdenv callPackage writeText;

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

    buildLuaRocks = { rockspec ? "", luadeps ? [] , buildInputs ? [] , ... }@args :
      let
        cfg = writeText "luarocs.lua" ''
            rocks_trees = {
                 { name = [[system]], root = [[${luarocks}]] }
               ${lib.concatImapStrings (i : dep :  ", { name = [[dep${toString i}]], root = [[${dep}]] }") luadeps}
            }
        '';
      in
      stdenv.mkDerivation (args // {
        buildInputs = buildInputs ++ [ luajit ];
        # FIXME: was originally preBuild
        configurePhase = ''
          makeFlagsArray=(
            PREFIX=$out
            LUA_LIBDIR="$out/lib/lua/${luajit.luaversion}"
            LUA_INC="-I${luajit}/include");
        '';
        buildPhase = ''
          runHook preBuild
          cp ${cfg} ./luarocks.lua
          export LUAROCKS_CONFIG=./luarocks.lua
          eval "`${luarocks}/bin/luarocks --deps-mode=all --tree=$out path`"
          ${luarocks}/bin/luarocks make --deps-mode=all --tree=$out ${rockspec}
          runHook postBuild
        '';
        dontInstall = true;
      });

    lua-cjson = buildLuaPackage {
      name = "lua-cjson";
      src = ./extra/lua-cjson;
    };

    luafilesystem = buildLuaRocks {
      name = "filesystem";
      src = ./extra/luafilesystem;
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
      buildInputs = [pkgs.cmake];
      rockspec = "rocks/${name}-scm-1.rockspec";
    };

    # TODO: merge buildTorch with generic buildLuaRocks
    buildTorch = { rockspec ? "", luadeps ? [] , buildInputs ? [] , preBuild ? "" , ... }@args :
      let
        mkcfg = ''
          export LUAROCKS_CONFIG=config.lua
          cat >config.lua <<EOF
            rocks_trees = {
                 { name = [[system]], root = [[${luarocks}]] }
               ${lib.concatImapStrings (i : dep :  ", { name = [[dep${toString i}]], root = [[${dep}]] }") luadeps}
            }

            variables = {
              LUA_BINDIR = "$out/bin";
              LUA_INCDIR = "$out/include";
              LUA_LIBDIR = "$out/lib/lua/${luajit.luaversion}";
            };
          EOF
        '';
      in
      stdenv.mkDerivation (args // {
        buildInputs = buildInputs ++ [ luajit ];
        phases = [ "unpackPhase" "patchPhase" "buildPhase" ];
        inherit preBuild;

        buildPhase = ''
          ${mkcfg}
          export LUA_PATH="$src/?.lua;$LUA_PATH"
          eval "`${luarocks}/bin/luarocks --deps-mode=all --tree=$out path`"
          ${luarocks}/bin/luarocks make --deps-mode=all --tree=$out ${rockspec}
        '';
      });

    torch = buildTorch rec {
      name = "torch";
      src = ./pkg/torch;
      luadeps = [ paths cwrap ];
      buildInputs = [ pkgs.cmake ];
      rockspec = "rocks/${name}-scm-1.rockspec";
      preBuild = ''
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
      buildInputs = [pkgs.readline];
      src = ./exe/trepl;
    };
  };

in

luapkgs

