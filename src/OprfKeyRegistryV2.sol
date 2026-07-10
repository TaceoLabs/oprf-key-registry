// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
}
