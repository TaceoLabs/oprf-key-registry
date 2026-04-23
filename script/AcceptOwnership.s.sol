// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";

contract AcceptOwnershipScript is Script {
    OprfKeyRegistry public oprfKeyRegistry;

    function setUp() public {
        oprfKeyRegistry = OprfKeyRegistry(vm.envAddress("OPRF_KEY_REGISTRY_PROXY"));
    }

    function run() public {
        vm.startBroadcast();
        oprfKeyRegistry.acceptOwnership();
        vm.stopBroadcast();
        console.log("Accepted ownership of OprfKeyRegistry at", address(oprfKeyRegistry));
    }
}
