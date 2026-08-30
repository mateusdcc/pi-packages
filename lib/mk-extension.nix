{ lib, pkgs }:

{
  pname,
  version ? "0.1.0",
  src,
  runtimePackages ? [ ],
  runtimeEnvironment ? { },
  piManifest ? { },
  meta ? { },
  passthru ? { },
  ...
}@args:

let
  cleanArgs = builtins.removeAttrs args [
    "pname"
    "version"
    "src"
    "runtimePackages"
    "runtimeEnvironment"
    "piManifest"
    "meta"
    "passthru"
  ];

  manifestJson = builtins.toJSON (
    lib.recursiveUpdate {
      name = pname;
      version = version;
      keywords = [ "pi-package" ];
      pi = {
        extensions = [ "./extensions" ];
      };
    } piManifest
  );
in
pkgs.stdenv.mkDerivation (
  cleanArgs
  // {
    pname = "pi-extension-${pname}";
    inherit version src;

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r ./* "$out/"

      if [ ! -f "$out/package.json" ]; then
        echo '${manifestJson}' > "$out/package.json"
      fi
      runHook postInstall
    '';

    passthru = passthru // {
      isPiExtension = true;
      inherit runtimePackages runtimeEnvironment;
    };

    meta = meta // {
      description = meta.description or "Pi extension package: ${pname}";
    };
  }
)
