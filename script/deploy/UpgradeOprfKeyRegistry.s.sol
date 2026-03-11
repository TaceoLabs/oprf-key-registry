// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OprfKeyRegistry} from "../../src/OprfKeyRegistry.sol";
import {OprfKeyRegistryV2} from "../../src/OprfKeyRegistryV2.sol";

contract UpgradeOprfKeyRegistryScript is Script {
    OprfKeyRegistry public oprfKeyRegistryProxy;
    address public oprfKeyRegistryNewImpl;

    function setUp() public {
        oprfKeyRegistryProxy = OprfKeyRegistry(vm.envAddress("OPRF_KEY_REGISTRY_PROXY"));
        oprfKeyRegistryNewImpl = vm.envAddress("OPRF_KEY_REGISTRY_NEW_IMPL");
    }

    function run() public {
        string memory environmentTag = vm.envString("ENVIRONMENT");
        string memory projectDs = vm.envString("PROJECT_DS");

        console.log(
            "Updating OPRF key-gen implementation from proxy",
            address(oprfKeyRegistryProxy),
            " to ",
            oprfKeyRegistryNewImpl
        );
        console.log("Initializing V2 with environment:", environmentTag);
        console.log("Initializing V2 with projectDs:", projectDs);

        bytes memory initV2Data =
            abi.encodeWithSelector(OprfKeyRegistryV2.initializeV2.selector, environmentTag, projectDs);

        vm.startBroadcast();
        OprfKeyRegistry(address(oprfKeyRegistryProxy)).upgradeToAndCall(oprfKeyRegistryNewImpl, initV2Data);
        vm.stopBroadcast();
    }
}
