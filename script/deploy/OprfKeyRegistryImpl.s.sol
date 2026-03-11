// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OprfKeyRegistryV2} from "../../src/OprfKeyRegistryV2.sol";

contract DeployOprfKeyRegistryImplScript is Script {
    OprfKeyRegistryV2 public oprfKeyRegistry;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy V2 implementation
        OprfKeyRegistryV2 implementation = new OprfKeyRegistryV2();

        vm.stopBroadcast();
        console.log("OprfKeyRegistryV2 implementation deployed to:", address(implementation));
    }
}
