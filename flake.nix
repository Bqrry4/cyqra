{
  description = "Cyqra build";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    c3c.url = "github:c3lang/c3c";    
  };

  outputs = { self, ... }@inputs:
   let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; }; 
      c3cPkg = inputs.c3c.packages.${system}.c3c;
   in
  {
    packages.${system} = {
      default = pkgs.stdenv.mkDerivation {
        name = "cyqra";
        src = ./.;
        nativeBuildInputs = [ c3cPkg ];
        buildPhase = "c3c build";
        installPhase = ''
          mkdir -p $out/bin
          mv build/cyqra $out/bin/
        '';
      };
    };
  };
}
