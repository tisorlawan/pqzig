with import <nixpkgs> { };
mkShell {
  buildInputs = [
    postgresql
    pkg-config
  ];
  LD_LIBRARY_PATH = lib.makeLibraryPath [
    stdenv.cc.cc
    postgresql
  ];
}
