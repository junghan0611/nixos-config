# Python development environment
{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    texinfo
    black
    isort
    basedpyright

    (python312.withPackages (ps: with ps; [
      ipdb
      ipykernel
      jupyter
      notebook
      jupyter_core
      jupyterlab
      pyzmq
      pandas
      tabulate
      flake8
    ]))
  ];
}
