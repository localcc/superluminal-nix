# Superluminal Profiler for NixOS

This is a repo that packages [Superluminal](https://superluminal.eu/) for NixOS.

## Installation

```nix
inputs = {
  superluminal = {
    url = "github:localcc/superluminal-nix";;
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

imports = [
  inputs.superluminal.nixosModules.default
];

programs.superluminal.enable = true;
```
