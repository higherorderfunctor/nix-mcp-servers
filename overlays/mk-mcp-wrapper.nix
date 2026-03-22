# mkMcpWrapper: creates a wrapper script with --stdio/--http dispatch
#
# name: binary name (e.g. "context7-mcp")
# version: package version string
# pkg: underlying derivation with the actual binary
# modes: { stdio = "...cmd..." or null; http = "...cmd..." or null; }
#   At least one of stdio or http must be non-null.
{writeShellApplication, ...}: {
  name,
  version,
  pkg,
  modes,
}: let
  hasStdio = modes ? stdio && modes.stdio != null;
  hasHttp = modes ? http && modes.http != null;
  flags =
    (
      if hasStdio
      then ["--stdio"]
      else []
    )
    ++ (
      if hasHttp
      then ["--http"]
      else []
    )
    ++ ["--version"];
  usage = "Usage: ${name} ${builtins.concatStringsSep "|" flags} [-- args...]";
  stdioCase =
    if hasStdio
    then ''
      --stdio) shift; [ "''${1:-}" = "--" ] && shift; exec ${modes.stdio} "$@" ;;
    ''
    else "";
  httpCase =
    if hasHttp
    then ''
      --http) shift; [ "''${1:-}" = "--" ] && shift; exec ${modes.http} "$@" ;;
    ''
    else "";
in
  assert hasStdio || hasHttp;
    writeShellApplication {
      inherit name;
      bashOptions = ["errexit" "nounset" "pipefail" "errtrace" "functrace"];
      runtimeInputs = [pkg];
      text = ''
        case "''${1:-}" in
          ${stdioCase}${httpCase}--version) echo "${name} ${version}"; exit 0 ;;
          *) echo "${usage}" >&2; exit 1 ;;
        esac
      '';
    }
