{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    luvit = {
      url = "github:luvit/luvit";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, luvit }: let
    system = "aarch64-darwin";
    pkgs = import nixpkgs { inherit system; };
    aiverson = {
      name = "Alex Iverson";
      email = "alexjiverson@gmail.com";
    };
  in {
    lib = with pkgs; with self.packages.${system}; rec {
      makeLuviScript = name: source:
        writeBinScript name "${luvi}/bin/luvi ${source} -- $@";
      luviBase = writeScript "luvi" ''
        #!${luvi}/bin/luvi --
      '';
      vendorLitDeps = { src, sha256, pname, ... }@args:
        stdenv.mkDerivation({
          name = "${pname}-vendoredpkgs";
          buildInputs = [ lit curl cacert ];
          phases = [ "unpackPhase" "configurePhase" "buildPhase" ];
          buildPhase = ''
            export HOME=./
            mkdir -p $out
            lit install || echo "work around bug"
            cp -r ./deps $out
          '';

          inherit src;

          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = sha256;
        });

      makeLitPackage = { buildInputs ? [ ], src, pname, litSha256, ... }@args:
        let
          deps = vendorLitDeps {
            inherit src pname;
            sha256 = litSha256;
          };
        in stdenv.mkDerivation ({
          buildPhase = ''
            echo database: `pwd`/.litdb.git >> litconfig
            export LIT_CONFIG=`pwd`/litconfig
            ln -s ${deps}/deps ./deps
            lit make . ./$pname ${luviBase} || echo "work around bug"
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp ./$pname $out/bin/$pname
          '';
        } // args // {
          buildInputs = [ lit luvi ] ++ buildInputs;
        });
    };

    # Specify the default package
    defaultPackage.${system} = self.packages.${system}.luvit;

    packages.${system} = with pkgs; with self.lib; rec {
      luvit = makeLitPackage rec {
        pname = "luvit";
        version = "2.17.0";

        litSha256 = "sha256-3EYdIjxF6XvFE3Ft6qpx/gaySMKiZi3kKr2K7QPB+G0=";

        src = inputs.luvit;

        meta = {
          description = "a lua runtime for application";
          homepage = "https://github.com/luvit/luvi";

          license = pkgs.lib.licenses.apsl20;
          maintainers = [ aiverson ];
        };
      };

      luvi = stdenv.mkDerivation rec {
        pname = "luvi";
        version = "2.14.0";

        src = pkgs.fetchFromGitHub {
          owner = "luvit";
          repo = "luvi";
          rev = "v${version}";
          sha256 = "h9Xdm/+9X3AoqBj1LJftqn3+3PbdankfAJSBP3KnRgw=";
          fetchSubmodules = true;
        };

        buildInputs = [ cmake openssl ];

        cmakeFlags = [
          "-DWithOpenSSL=ON"
          "-DWithSharedOpenSSL=ON"
          "-DWithPCRE=ON"
          "-DWithLPEG=ON"
          "-DWithSharedPCRE=OFF"
          "-DLUVI_VERSION=${version}"
        ];

        patchPhase = ''
          echo ${version} >> VERSION
        '';
        installPhase = ''
          mkdir -p $out/bin
          cp luvi $out/bin/luvi
        '';

        meta = {
          description = "a lua runtime for applications";
          homepage = "https://github.com/luvit/luvi";

          license = pkgs.lib.licenses.apsl20;
          maintainers = [ aiverson ];
        };
      };


      lit = stdenv.mkDerivation rec {
        pname = "lit";
        version = "3.8.5";

        src = pkgs.fetchFromGitHub {
          owner = "luvit";
          repo = "lit";
          rev = "${version}";
          sha256 = "sha256-8Fy1jIDNSI/bYHmiGPEJipTEb7NYCbN3LsrME23sLqQ=";
          fetchSubmodules = true;
        };

        buildInputs = [ luvi ];
        buildPhase = ''
          echo database: `pwd`/.litdb.git >> litconfig
          export LIT_CONFIG=`pwd`/litconfig
          ${luvi}/bin/luvi . -- make . ./lit ${luviBase} || echo work around bug
        '';
        installPhase = ''
          mkdir -p $out/bin
          cp lit $out/bin/lit
        '';

        meta = {
          description = "packaging tool for luvit";
          homepage = "https://github.com/luvit/lit";

          license = pkgs.lib.licenses.apsl20;
          maintainers = [ aiverson ];
        };
      };
    };
  };
}
