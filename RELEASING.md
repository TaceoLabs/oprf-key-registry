# Releasing

The registry is a UUPS-upgradeable contract behind an `ERC1967Proxy`. The released, deployed
version keeps its contract name forever (v1 is `OprfKeyRegistry`, v2 is `OprfKeyRegistryV2`, ...);
it serves as the reference for storage-layout validation of the next version.

## Staging the next version

1. Create `src/Unreleased<Name>VN.sol` with a contract that **inherits the previous released
   version** (e.g. `contract UnreleasedOprfKeyRegistryV3 is OprfKeyRegistryV2`). Storage is
   append-only via inheritance: never modify or reorder state in a released contract, only append
   new variables in the derived contract. There is intentionally no `__gap` (see the note in
   `OprfKeyRegistry.sol`).
2. Annotate the contract with `/// @custom:oz-upgrades-from <PreviousContract>` and keep a
   NatSpec change list of everything the version adds.
3. If the new version adds state that needs initialization, add an
   `initializeVN() reinitializer(N)` function and call it via `upgradeToAndCall`.
4. CI validates upgrade safety on every push (`.github/workflows/is_upgradable.yml`, backed by
   `@openzeppelin/upgrades-core validate`). Run it locally with:

   ```sh
   forge clean && forge build
   npx @openzeppelin/upgrades-core validate --unsafeAllowLinkedLibraries --exclude "**/*.t.sol"
   ```

5. Add tests: behavior tests for the new functions, and an upgrade test that deploys the previous
   version, runs a flow, upgrades, and asserts state is preserved (pattern:
   `test/OprfKeyRegistryUpgrade.t.sol`).

## Cutting a release

1. Rename the staged files and contracts, dropping the `Unreleased` prefix
   (`UnreleasedOprfKeyRegistryV3` -> `OprfKeyRegistryV3`), and update all references in
   `test/` and `script/deploy/`. Keep the `@custom:oz-upgrades-from` annotation.
2. Point the deploy scripts at the new version so fresh deployments start on it
   (`script/deploy/OprfKeyRegistryImpl.s.sol`, `OprfKeyRegistry.s.sol`,
   `OprfKeyRegistryWithDeps.s.sol`).
3. Regenerate the changelog: `just changelog` (git-cliff over conventional commits, config in
   `cliff.toml`).
4. Merge, then tag: `git tag vX.Y.Z && git push origin vX.Y.Z`. The tag triggers
   `.github/workflows/release.yml`, which creates a GitHub Release with git-cliff notes.

## Upgrading the deployed proxy

1. Deploy the new implementation: `just deploy-oprf-key-registry-impl` (dry-run variant available).
2. Execute the upgrade from the proxy owner. Set `OPRF_KEY_REGISTRY_PROXY` and
   `OPRF_KEY_REGISTRY_NEW_IMPL`, then either run `just upgrade-oprf-key-registry` directly, or,
   when the owner is a Safe, generate a Transaction Builder batch with
   `just safe-tx script/deploy/UpgradeOprfKeyRegistry.s.sol <chain_id> <safe_addr>` and upload it via
   app.safe.global.
3. Verify the new implementation on the block explorer and check the proxy reports the new
   version (e.g. `supportsInterface` for v2+).
