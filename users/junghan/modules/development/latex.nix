# LaTeX development environment
{ config, lib, pkgs, currentSystemName ? "", ... }:

let
  isOracle = currentSystemName == "oracle";
  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-medium
      dvisvgm
      dvipng        # for preview and export as html
      wrapfig
      amsmath
      ulem
      hyperref
      capt-of
      parskip;
  });
in {
  # Oracle(헤드리스, 저장공간 민감)에서는 texlive(~2.6 GB) 제외
  home.packages = lib.optionals (!isOracle) [ tex ];
}
