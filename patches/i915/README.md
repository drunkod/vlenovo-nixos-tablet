# i915 patch staging area

No kernel patch is selected yet.

Only add a patch here after a reproducible graphics defect has been isolated
to i915 and checked against current upstream Linux. Prefer, in order:

1. an existing upstream fix/backport;
2. a narrowly scoped Lenovo Miix 2 10 quirk;
3. a generic Valleyview fix only when the defect is proven generic.

Every patch must be tested with a separate NixOS generation using
`nixos-rebuild test` before it can become permanent.

Target identity:

- GPU: Intel Valleyview / Bay Trail `8086:0f31`
- subsystem: Lenovo `17aa:3901`
- DMI product: Lenovo Miix 2 10 / `20359`
- internal display: MIPI-DSI, 1920x1200@60
