{
  description = "Lenovo Miix 2 10: reversible Flick GPU NixOS generation candidate";

  inputs = {
    integration.url = "github:drunkod/vlenovo-nixos-tablet/a3dcc0637b92bff7c30bc8914bda6ee1a3f50281";
    gpuCandidate.url = "github:drunkod/vlenovo-nixos-tablet/20555d76e065e693a8f2b1f63b8f4fad80f427e1?dir=experiments/flick-build";
  };

  outputs = { self, integration, gpuCandidate, ... }:
    let
      testedPackage = gpuCandidate.packages.x86_64-linux.flick-qt-egl-qml-system;
    in {
      packages.x86_64-linux.flick-gpu = testedPackage;

      nixosConfigurations.vlenovo =
        integration.nixosConfigurations.vlenovo.extendModules {
          modules = [
            ({ lib, config, ... }: {
              services.flick.package = lib.mkForce testedPackage;
              assertions = [
                {
                  assertion = config.services.flick.enable
                    && config.services.flick.autostart;
                  message = "GPU generation requires the known Flick DRM autostart configuration";
                }
              ];
            })
          ];
        };
    };
}
