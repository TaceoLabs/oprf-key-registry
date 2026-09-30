# Test fixtures

`OprfKeyRegistryV2_v2.0.0.bin`: creation bytecode of `OprfKeyRegistryV2` as released in v2.0.0 (built from `main`
at `afd1f58` with the repo's `foundry.toml`), with the `BabyJubJub` library statically linked to
`0x0000000000000000000000000000000000BAB1E5`. Used by `OprfKeyRegistryUpgradeFromV2Bytecode.t.sol` to upgrade a
proxy running the old storage layout to the current implementation.

Regenerate from a checkout of the old revision (with `lib/` populated):

```sh
forge build --libraries "lib/babyjubjub-solidity/src/BabyJubJub.sol:BabyJubJub:0x0000000000000000000000000000000000BAB1E5"
jq -r .bytecode.object out/OprfKeyRegistryV2.sol/OprfKeyRegistryV2.json > test/fixtures/OprfKeyRegistryV2_v2.0.0.bin
```
