{
  pkgs,
  fetchFromGitHub ? pkgs.fetchFromGitHub,
}:

pkgs.stdenv.mkDerivation rec {
  pname = "archify";
  version = "2.16.0";

  src = fetchFromGitHub {
    owner = "tt-a1i";
    repo = "archify";
    rev = "12106be58b34f94b108ab30f6ac0eb37c16a8f71";
    hash = "sha256-+v1taBFPv6uFsitP0o3L60KPU59iKM+SA87r4d92O30=";
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/archify $out/bin
    cp -r archify/* $out/lib/archify/
    chmod +x $out/lib/archify/bin/archify.mjs

    makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/archify \
      --add-flags "$out/lib/archify/bin/archify.mjs"
    runHook postInstall
  '';

  passthru = {
    runtimePackages = with pkgs; [
      nodejs_22
      coreutils
      jq
    ];
  };

  meta = with pkgs.lib; {
    description = "Turn codebases into interactive, validated system and architecture maps";
    homepage = "https://github.com/tt-a1i/archify";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "archify";
  };
}
