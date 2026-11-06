# bridge-v2-proptests

Foundry property-test harnesses for Mt Pelerin bridge-v2 (Solidity 0.6.2), consumed
by the Asgard Hofund toolchain (echidna + halmos). Each `*Proptest` contract inherits a
compliance rule and declares `echidna_*` / `check_*` / `invariant_*` functions.

The Hofund echidna/halmos wrappers install the `@openzeppelin/*` npm packages and
rewrite their imports to relative paths before compiling, so this repo contains only
sources (no `node_modules`).

## Rules covered

- Transfer thresholds: `MinTransferRule`, `MaxTransferRule`, `HardTransferLimitRule`
- Freeze: `GlobalFreezeRule`, `UserFreezeRule`
- KYC/validity: `UserValidRule`
- Vesting: `VestingRule`
- Test rules: `YesNoRule`, `YesNoUpdateRule`
