#!/usr/bin/env bash

sudo cp * /etc/nixos/
cd /etc/nixos
sudo nixos-rebuild switch
cd -
