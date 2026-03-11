// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {OprfKeyRegistryV2} from "../src/OprfKeyRegistryV2.sol";

contract DeleteOprfKeyScript is Script {
    OprfKeyRegistryV2 public oprfKeyRegistry;

    function setUp() public {
        oprfKeyRegistry = OprfKeyRegistryV2(vm.envAddress("OPRF_KEY_REGISTRY_PROXY"));
    }

    function run() public {
        uint160 oprfKeyId = uint160(vm.envUint("OPRF_KEY_ID"));
        vm.startBroadcast();
        oprfKeyRegistry.deleteOprfPublicKey(oprfKeyId);
        vm.stopBroadcast();

        console.log("Deleted OPRF public-key", oprfKeyId, "from OprfKeyRegistry at: ", address(oprfKeyRegistry));
    }
}
