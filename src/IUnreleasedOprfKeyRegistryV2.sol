// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOprfKeyRegistry} from "./IOprfKeyRegistry.sol";
import {OprfKeyGen} from "./OprfKeyGen.sol";

interface IUnreleasedOprfKeyRegistryV2 is IOprfKeyRegistry {
    /// @notice Emitted when `reportKeyGenStuck` marks an active key-gen/reshare process as stuck.
    /// @param oprfKeyId The unique identifier for the OPRF key process.
    /// @param reporter The registered OPRF peer that reported the process as stuck.
    /// @param previousRound The round the process was in immediately before being marked stuck.
    event KeyGenStuckReported(uint160 indexed oprfKeyId, address indexed reporter, OprfKeyGen.Round previousRound);

    /// @notice Allows a registered OPRF node to report an active key-gen/reshare is stuck.
    /// @param oprfKeyId The unique identifier for the OPRF key process.
    function reportKeyGenStuck(uint160 oprfKeyId) external;

    /// @notice Returns the list of registered OPRF peer addresses, indexed by party ID.
    /// @return The registered peer addresses in party-ID order.
    function getPeerAddresses() external view returns (address[] memory);

    /// @notice Checks whether the given address is a registered OPRF participant.
    /// @param addr The address to check.
    /// @return True if `addr` is a registered participant.
    function isParticipant(address addr) external view returns (bool);
}
