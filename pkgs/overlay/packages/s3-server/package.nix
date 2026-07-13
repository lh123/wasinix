{final, ...}: let
  inherit (final) lib;
in
  final.rustPlatform.buildRustPackage {
    pname = "s3-server";
    version = "0.1.17";
    src = final.fetchFromGitHub {
      owner = "wasix-org";
      repo = "s3-server";
      rev = "a82795d558d81eb7a98b7a203775e57a675ad637";
      hash = "sha256-q3/C59rThhfNzwd6zUptQrcy/EZEvIG6RTSpe/8QqBQ=";
    };
    # the CLI (structopt/dotenv/tracing-subscriber) is behind the binary feature.
    buildFeatures = ["binary"];
    cargoHash = "sha256-iq6FnobEju7DIHacvoFPTTJDhCKMY3R4NE/QQKWiW9I=";

    passthru.wasix.shipped = true;

    meta = {
      description = "Generic S3 server (wasix-org fork), built to WASIX";
      homepage = "https://github.com/wasix-org/s3-server";
      license = lib.licenses.mit;
      mainProgram = "s3-server";
    };
  }
