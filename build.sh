#!/usr/bin/env bash

sudo cp nixos/* /etc/nixos/
sudo nixos-rebuild switch
