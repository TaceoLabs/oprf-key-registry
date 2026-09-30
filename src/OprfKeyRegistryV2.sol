// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BabyJubJub} from "@taceo/babyjubjub/BabyJubJub.sol";
import {OprfKeyGen} from "./OprfKeyGen.sol";
import {OprfKeyRegistry} from "./OprfKeyRegistry.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {IOprfKeyRegistry} from "./IOprfKeyRegistry.sol";
import {IOprfKeyRegistryV2} from "./IOprfKeyRegistryV2.sol";

/// @title OPRF Key Registry V2
/// @notice Second version of `OprfKeyRegistry`, deployed via proxy upgrade from `OprfKeyRegistry`.
/// @dev Change list for this version:
/// - Adds `reportKeyGenStuck(uint160)` so registered nodes can report key-generation/reshare processes as stuck.
/// - Adds ERC165 support.
/// - Adds `getPeerAddresses`. Returns the full array of addresses of registered peers
/// - Adds `isParticipant(address addr)`. Returns true iff the provided address is in the list of participants
/// - Bumps `babyjubjub-solidity` to v1.2.0 and overrides `_curveChecks` to use the cheaper Tate-pairing based
///   subgroup membership check (`BabyJubJub.isValidPoint`). Accepts exactly the same set of points as before.
/// - Reworks the per-key round bookkeeping: round data lives in party-id keyed mappings and submissions are
///   tracked in bitmasks appended to `OprfKeyGenState`. Nothing is zeroed or re-allocated between runs anymore,
///   which removes most of the storage cost of `initKeyGen`/`initReshare`, round 1 and the finalizing round 3.
///   The legacy array fields stay in place (storage layout unchanged, see test/OprfKeyRegistryUpgradeFromV2Bytecode.t.sol).
///   Upgrade prerequisite: key-gens/reshares that are in progress at upgrade time cannot be continued and must be
///   aborted (`abortKeyGen`) and restarted; finalized keys and their share commitments carry over unchanged.
/// - Round 2 ciphertexts are emitted (`Round2Ciphers`) instead of stored; `checkIsParticipantAndReturnRound2Ciphers`
///   is removed. Peers collect the ciphertexts from the events of the current run.
/// @custom:oz-upgrades-from OprfKeyRegistry
contract OprfKeyRegistryV2 is OprfKeyRegistry, IOprfKeyRegistryV2, ERC165 {
    /// @inheritdoc IOprfKeyRegistryV2
    function reportKeyGenStuck(uint160 oprfKeyId) public virtual onlyProxy isReady {
        if (!addressToPeer[msg.sender].isParticipant) revert NotAParticipant();

        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        OprfKeyGen.Round currentRound = st.currentRound;

        if (currentRound == OprfKeyGen.Round.NOT_STARTED) revert UnknownId(oprfKeyId);
        if (currentRound == OprfKeyGen.Round.DELETED) revert DeletedId(oprfKeyId);
        if (
            currentRound != OprfKeyGen.Round.ONE && currentRound != OprfKeyGen.Round.TWO
                && currentRound != OprfKeyGen.Round.THREE
        ) {
            revert WrongRound(currentRound);
        }

        st.currentRound = OprfKeyGen.Round.STUCK;
        emit KeyGenStuckReported(oprfKeyId, msg.sender, currentRound);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IOprfKeyRegistry).interfaceId || interfaceId == type(IOprfKeyRegistryV2).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IOprfKeyRegistryV2
    function getPeerAddresses() public view virtual onlyProxy returns (address[] memory) {
        return peerAddresses;
    }

    /// @inheritdoc IOprfKeyRegistryV2
    function isParticipant(address addr) public view virtual onlyProxy returns (bool) {
        return addressToPeer[addr].isParticipant;
    }

    /// @dev Same checks as `OprfKeyRegistry._curveChecks` (rejects identity, off-curve and non-prime-order points),
    ///      but uses the Tate-pairing based subgroup check.
    function _curveChecks(BabyJubJub.Affine memory element) internal view virtual override {
        if (BabyJubJub.isIdentity(element) || !BabyJubJub.isValidPoint(element)) revert BadContribution();
    }
}
