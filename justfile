[private]
default:
    @just --justfile {{ justfile() }} --list --list-heading $'Project commands:\n'

[group('build')]
export-contract-abi:
    forge build --silent && jq '.abi' out/OprfKeyRegistry.sol/OprfKeyRegistry.json > ../oprf-types/OprfKeyRegistry.json
    cp out/VerifierKeyGen13.sol/Verifier.json ../oprf-test-utils/contracts/Verifier.13.json
    cp out/VerifierKeyGen25.sol/Verifier.json ../oprf-test-utils/contracts/Verifier.25.json
    cp out/BabyJubJub.sol/BabyJubJub.json ../oprf-test-utils/contracts/BabyJubJub.json
    cp out/TestOprfKeyRegistry.sol/TestOprfKeyRegistry.json ../oprf-test-utils/contracts
    cp out/ERC1967Proxy.sol/ERC1967Proxy.json ../oprf-test-utils/contracts

[group('test')]
contract-tests:
    forge test

[group('build')]
show-contract-errors:
    forge inspect src/OprfKeyRegistry.sol:OprfKeyRegistry errors
    forge inspect src/VerifierKeyGen13.sol:Verifier errors
    forge inspect src/VerifierKeyGen25.sol:Verifier errors

[group('build')]
show-contract-methods:
    forge inspect src/OprfKeyRegistry.sol:OprfKeyRegistry methodIdentifiers

[group('deploy')]
deploy-oprf-key-registry-with-deps-dry-run *args:
    forge script OprfKeyRegistryWithDeps.s.sol -vvvvv {{ args }}

[group('deploy')]
deploy-oprf-key-registry-with-deps *args:
    forge script OprfKeyRegistryWithDeps.s.sol --broadcast --interactives 1 -vvvvv {{ args }} --rpc-url $RPC_URL --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY

[group('deploy')]
deploy-oprf-key-registry-dry-run *args:
    forge script OprfKeyRegistry.s.sol -vvvvv {{ args }}

[group('deploy')]
deploy-oprf-key-registry *args:
    forge script OprfKeyRegistry.s.sol --broadcast --interactives 1 -vvvvv {{ args }} --rpc-url $RPC_URL --verify --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY

[group('contract')]
register-participants *args:
    forge script RegisterParticipants.s.sol --broadcast --interactives 1 -vvvvv {{ args }} --rpc-url $RPC_URL

[group('contract')]
register-participants-dry-run *args:
    forge script RegisterParticipants.s.sol -vvvvv {{ args }}

[group('contract')]
revoke-key-gen-admin-dry-run *args:
    forge script RevokeKeyGenAdmin.s.sol -vvvvv {{ args }}

[group('contract')]
revoke-key-gen-admin *args:
    forge script RevokeKeyGenAdmin.s.sol -vvvvv --broadcast --interactives 1 {{ args }} --rpc-url $RPC_URL

[group('contract')]
register-key-gen-admin-dry-run *args:
    forge script RegisterKeyGenAdmin.s.sol -vvvvv {{ args }}

[group('contract')]
register-key-gen-admin *args:
    forge script RegisterKeyGenAdmin.s.sol -vvvvv --broadcast --interactives 1 {{ args }} --rpc-url $RPC_URL

[group('anvil')]
deploy-oprf-key-registry-with-deps-anvil:
    TACEO_ADMIN_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 THRESHOLD=2 NUM_PEERS=3 forge script OprfKeyRegistryWithDeps.s.sol --broadcast --fork-url http://127.0.0.1:8545 -vvvvv --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

[group('anvil')]
deploy-oprf-key-registry-anvil:
    TACEO_ADMIN_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 THRESHOLD=2 NUM_PEERS=3 forge script OprfKeyRegistry.s.sol --broadcast --fork-url http://127.0.0.1:8545 -vvvvv --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

[group('anvil')]
register-participants-anvil:
    PARTICIPANT_ADDRESSES=0x14dC79964da2C08b23698B3D3cc7Ca32193d9955,0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f,0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 forge script RegisterParticipants.s.sol --broadcast --fork-url http://127.0.0.1:8545 -vvvvv --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

[group('anvil')]
revoke-key-gen-admin-anvil:
    forge script RevokeKeyGenAdmin.s.sol --broadcast --fork-url http://127.0.0.1:8545 -vvvvv --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

[group('anvil')]
register-key-gen-admin-anvil:
    forge script RegisterKeyGenAdmin.s.sol --broadcast --fork-url http://127.0.0.1:8545 -vvvvv --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
