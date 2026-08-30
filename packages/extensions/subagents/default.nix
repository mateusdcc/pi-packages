{
  pkgs,
  fetchFromGitHub ? pkgs.fetchFromGitHub,
  buildNpmPackage ? pkgs.buildNpmPackage,
}:

buildNpmPackage {
  pname = "pi-subagents";
  version = "0.58.0";

  src = fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-subagents";
    rev = "58732918f7a92c786ce537e3a56e41bbfb6f86ee";
    hash = "sha256-JVH4kLyaW7nElDQf2XzoSALhWyO3una4uG7aK146S+0=";
  };

  npmDepsHash = "sha256-BixrOUy1n+Xa4H88FP7lV08d2DfO0fhfGZBrg030MA0=";
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r * $out/
    runHook postInstall
  '';

  passthru = {
    isPiExtension = true;
    runtimePackages = with pkgs; [
      nodejs_22
      coreutils
      git
      jq
      ripgrep
    ];
  };

  meta = {
    description = "Pi subagents extension for single-agent delegation and scripted multi-agent workflows";
    homepage = "https://github.com/nicobailon/pi-subagents";
    license = pkgs.lib.licenses.mit;
  };
}
