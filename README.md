## Key Registry Contract for TACEO:OPRF

This repository is part of the [TACEO:OPRF](https://github.com/TaceoLabs/oprf-service) project and holds the smart contracts that act as an on-chain registry for OPRF Node parties and the generated OPRF keys.

The contract provides functionality to initiate a new key generation protocol run, with the contract itself being used as a public message board for the parties' messages during the protocol.
In addition it can also be used to trigger a key reshare procedure, which is similar to the key generation procedure, but refreshes the parties' key shares, keeping the underlying OPRF key the same.

### Contract Versions

#### OprfKeyRegistry (V1)

The base upgradeable contract (UUPS proxy pattern) implementing the full MPC key generation and reshare protocol.

#### OprfKeyRegistryV2

Upgrades the registry with the following additions:

- **ERC-165 support** — implements `supportsInterface` and declares the `IOprfKeyRegistryMpc` interface ID, enabling on-chain interface discovery.
- **Domain tag** — a `bytes32 domainTag` derived from a restricted environment enum and a project identifier:
  ```
  keccak256("<env>-<projectDs>-TACEO:OPRF")
  ```
  The environment must be one of the `Environment` enum variants: `Test` → `"test"`, `Stage` → `"stage"`, `Prod` → `"prod"`.
  Set once via `initializeV2` (called after upgrading the proxy) and optionally updated later via `updateDomainTag`.
- **`contractCompCheck`** — a view function that asserts the contract matches a caller's expected interface ID, domain tag, peer count, and threshold, reverting with `ContractComp()` if any parameter mismatches. Intended for off-chain nodes to verify they are connected to the correct contract instance.

### Upgrading to V2

1. Deploy `OprfKeyRegistryV2` as a new implementation.
2. Call `upgradeToAndCall` on the existing proxy, encoding `initializeV2(Environment, projectDs)` as the calldata so the domain tag is set atomically in the same transaction. Use the `ENVIRONMENT` env var (0=Test, 1=Stage, 2=Prod) with the upgrade just command.
