{
  final,
  nix-update-script,
  ...
}: let
  inherit (final) lib;
in
  final.rustPlatform.buildRustPackage (finalAttrs: {
    pname = "s3-server";
    version = "0.1.22";
    src = final.fetchFromGitHub {
      owner = "wasix-org";
      repo = "s3-server";
      tag = finalAttrs.version;
      hash = "sha256-SjcTkqfuEAXpJzFhlQaFfIhBQ7RZFo8uIK8S6ph5zi0=";
    };

    # the CLI (structopt/dotenv/tracing-subscriber) is behind the binary feature.
    buildFeatures = ["binary"];
    cargoHash = "sha256-iq6FnobEju7DIHacvoFPTTJDhCKMY3R4NE/QQKWiW9I=";

    passthru.updateScript = nix-update-script {
      extraArgs = ["--flake" "--version-regex" "^([0-9.]+)$"];
    };

    passthru.wasix.shipped = true;

    meta = {
      description = "Generic S3 server (wasix-org fork), built to WASIX";
      homepage = "https://github.com/wasix-org/s3-server";
      license = lib.licenses.mit;
      mainProgram = "s3-server";
    };
  })
