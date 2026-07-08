// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OprfKeyGen} from "./OprfKeyGen.sol";
import {OprfKeyRegistry} from "./OprfKeyRegistry.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {IOprfKeyRegistry} from "./IOprfKeyRegistry.sol";
import {IUnreleasedOprfKeyRegistryV2} from "./IUnreleasedOprfKeyRegistryV2.sol";

/// @title Unreleased OPRF Key Registry V2
/// @notice Next unreleased version of `OprfKeyRegistry` intended for proxy upgrades.
/// @dev Change list for this version:
/// - Adds `reportKeyGenStuck(uint160)` so registered nodes can report key-generation/reshare processes as stuck.
/// - Adds ERC165 support.
/// @custom:oz-upgrades-from OprfKeyRegistry
contract UnreleasedOprfKeyRegistryV2 is OprfKeyRegistry, IUnreleasedOprfKeyRegistryV2, ERC165 {
    /// @notice Allows a registered OPRF node to report an active key-gen/reshare is stuck.
    /// @param oprfKeyId The unique identifier for the OPRF key process.
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
        return interfaceId == type(IOprfKeyRegistry).interfaceId
            || interfaceId == type(IUnreleasedOprfKeyRegistryV2).interfaceId || super.supportsInterface(interfaceId);
    }
}
