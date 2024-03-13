{ pkgs, inputs, ... }:

let
  # pinned terraform, because post 1.6 it's marked 'unfree' (BSL)
  pinned-terraform-nixpkgs = import inputs.nixpkgs-for-terraform { system = pkgs.stdenv.system; };
in
{
  packages = with pkgs; [
    pinned-terraform-nixpkgs.terraform
  ];
}
