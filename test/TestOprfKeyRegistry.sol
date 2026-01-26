// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OprfKeyGen} from "../src/OprfKeyGen.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";

contract TestOprfKeyRegistry is OprfKeyRegistry {
    function emitDeleteEvent(uint160 oprfKeyId) public {
        emit OprfKeyGen.KeyDeletion(oprfKeyId);
    }
}
