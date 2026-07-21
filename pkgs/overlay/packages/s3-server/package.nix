{
  final,
  nix-update-script,
  ...
}: let
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
    # vendored pending upstream (wasix-org/s3-server); neither touches Cargo.lock,
    # so cargoHash is unchanged (see wasix.updateNotes)
    patches = [
      ./patches/0001-fix-store-metadata-multipart-parts-in-a-reserved-dir.patch
      ./patches/0002-fix-recursive-listing-idempotent-delete-directory-ke.patch
    ];
    # the CLI (structopt/dotenv/tracing-subscriber) is behind the binary feature.
    buildFeatures = ["binary"];
    cargoHash = "sha256-iq6FnobEju7DIHacvoFPTTJDhCKMY3R4NE/QQKWiW9I=";

    # Stable tags only: a published webc version is semver MAJOR.MINOR.PATCH, so
    # a prerelease tag (0.1.20-rc.1) has a fourth component with nowhere to go,
    # and the registry hides prereleases from `latest` anyway (WASIX-TODO.md).
    passthru.updateScript = nix-update-script {
      extraArgs = ["--flake" "--version-regex" "^([0-9.]+)$"];
    };

    passthru.wasix = {
      shipped = true;
      updateNotes = [
        {message = "the fork's only tag is 0.1.20-rc.1; until it cuts a stable one the update target fails with \"No version matched the regex\" (prereleases are excluded on purpose, see updateScript)";}
        {message = "drop patches/0001-fix-store-metadata-multipart-parts-in-a-reserved-dir.patch and bump the rev once the fix merges into wasix-org/s3-server";}
        {message = "drop patches/0002-fix-recursive-listing-idempotent-delete-directory-ke.patch and bump the rev once the fix merges into wasix-org/s3-server";}
      ];
    };

    meta = {
      description = "Generic S3 server (wasix-org fork), built to WASIX";
      homepage = "https://github.com/wasix-org/s3-server";
      license = lib.licenses.mit;
      mainProgram = "s3-server";
    };
  }
