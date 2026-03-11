// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOprfKeyRegistry, IOprfKeyRegistryMpc, OprfKeyRegistry} from "./OprfKeyRegistry.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

string constant OPRF_TAG = "TACEO:OPRF";

/// @custom:oz-upgrades-from OprfKeyRegistry
/// @title Upgradeable OPRF Key Registry V2
/// @notice Adds upgrade-safe domain tag initialization for proxies
contract OprfKeyRegistryV2 is OprfKeyRegistry, ERC165 {
    /// @notice The domain tag identifying environment and project context
    /// @dev Mutable to allow proxy initialization
    bytes32 public domainTag;

    /// @notice Error thrown when a contract does not match expected parameters
    error ContractComp();

    /// @notice Emitted whenever the domain tag is updated
    /// @param oldDomainTag The previous domain tag
    /// @param newDomainTag The new domain tag
    event DomainTagUpdated(bytes32 indexed oldDomainTag, bytes32 indexed newDomainTag);

    /// @notice Initializes V2-specific state for upgradeable proxies
    /// @param _environmentTag The deployment environment
    /// @param _projectDs The project identifier
    /// @dev Must be called **once** after upgrading to V2
    function initializeV2(string calldata _environmentTag, string calldata _projectDs)
        public
        reinitializer(2)
        onlyOwner
    {
        _updateDomainTag(_environmentTag, _projectDs);
    }

    /// @notice Optionally allows manual update of domain tag
    /// @param _environmentTag The deployment environment
    /// @param _projectDs The project identifier
    /// @dev Only callable by owner via proxy
    function updateDomainTag(string calldata _environmentTag, string calldata _projectDs)
        public
        virtual
        onlyOwner
        onlyProxy
    {
        _updateDomainTag(_environmentTag, _projectDs);
    }

    /// @notice Checks whether the contract implements a given interface
    /// @param interfaceId The ERC-165 interface ID to check
    /// @return True if the contract supports the interface, false otherwise
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IOprfKeyRegistryMpc).interfaceId || interfaceId == type(IOprfKeyRegistry).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice Validates that the contract matches expected interface and configuration
    /// @param _interfaceId The expected ERC-165 interface ID
    /// @param _domainTag The expected domain tag
    /// @param _numPeers The expected number of MPC peers
    /// @param _threshold The expected MPC threshold
    function contractCompCheck(bytes4 _interfaceId, bytes32 _domainTag, uint16 _numPeers, uint16 _threshold)
        public
        view
        virtual
    {
        if (
            !supportsInterface(_interfaceId) || domainTag != _domainTag || numPeers != _numPeers
                || threshold != _threshold
        ) {
            revert ContractComp();
        }
    }

    function _updateDomainTag(string calldata _environmentTag, string calldata _projectDs) internal virtual {
        bytes32 oldTag = domainTag;
        domainTag = keccak256(bytes(string.concat(_environmentTag, "-", _projectDs, "-", OPRF_TAG)));
        emit DomainTagUpdated(oldTag, domainTag);
    }
}
