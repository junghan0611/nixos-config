# entwurf × OpenClaw — host shim to the operating Gateway CLI (oracle only, #160 step 5)
#
# entwurf's OpenClaw adapter runs `<bin> gateway call … --expect-url <url>`. On oracle the Gateway
# lives in the `openclaw-gateway` container, so `bin` is this shim: it forwards argv to the CLI
# inside that container. Procedure: docs/openclaw-entwurf-desk.md.
#
# Boundaries:
# - Not on PATH and not named bare `openclaw`: a stray `openclaw …` typed on the host must not run
#   inside the operating container. The declaration (`~/.pi/agent/openclaw-citizens.json`
#   gateway.bin) names this absolute path.
# - `-i` only, never `-t`. The container name is a literal; no argument or env can change it.
# - `OPENCLAW_CONFIG_PATH` is refused: docker exec does not carry host env into the container, so
#   honouring it silently would be a lie. entwurf's parser already refuses bin + configPath.
{ pkgs, ... }:
let
  shim = pkgs.writeShellScript "openclaw-oracle-gateway" ''
    if [ -n "''${OPENCLAW_CONFIG_PATH+x}" ]; then
      echo "openclaw-oracle-gateway: OPENCLAW_CONFIG_PATH does not reach the container; refusing" >&2
      exit 64
    fi
    exec /run/current-system/sw/bin/docker exec -i openclaw-gateway openclaw "$@"
  '';
in
{
  home.file.".local/libexec/entwurf/openclaw-oracle-gateway".source = shim;
}
