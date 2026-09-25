{
  lib,
  rustPlatform,
}:

let
  manifest = (lib.importTOML ../Cargo.toml).package;
in
rustPlatform.buildRustPackage {
  pname = manifest.name;
  inherit (manifest) version;

  # Only the files cargo reads, so editing the README, the worker or the
  # installers does not rebuild the daemon.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Cargo.toml
      ../Cargo.lock
      ../src
    ];
  };

  cargoLock.lockFile = ../Cargo.lock;

  meta = {
    inherit (manifest) description;
    homepage = "https://github.com/mael-app/os-tracker";
    license = lib.licenses.mit;
    mainProgram = "os-tracker";
    platforms = lib.platforms.unix;
  };
}
