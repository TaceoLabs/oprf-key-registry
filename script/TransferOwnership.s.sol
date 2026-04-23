// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";

contract TransferOwnershipScript is Script {
    OprfKeyRegistry public oprfKeyRegistry;

    function setUp() public {
        oprfKeyRegistry = OprfKeyRegistry(vm.envAddress("OPRF_KEY_REGISTRY_PROXY"));
    }

    function run() public {
        address newOwner = vm.envAddress("NEW_OWNER");
        vm.startBroadcast();
        oprfKeyRegistry.transferOwnership(newOwner);
        vm.stopBroadcast();
        console.log("Set pending owner of OprfKeyRegistry at", address(oprfKeyRegistry), "to", newOwner);
    }
}
