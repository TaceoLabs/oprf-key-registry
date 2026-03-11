// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OprfKeyRegistryV2} from "../src/OprfKeyRegistryV2.sol";

contract PrintInformationScript is Script {
    OprfKeyRegistryV2 public oprfKeyRegistry;

    function setUp() public {
        oprfKeyRegistry = OprfKeyRegistryV2(vm.envAddress("OPRF_KEY_REGISTRY_PROXY"));
    }

    function run() external {
        vm.startBroadcast();
        bool isContractReady = oprfKeyRegistry.isContractReady();
        uint256 amountAdmins = oprfKeyRegistry.amountKeygenAdmins();
        address keyGenVerifier = oprfKeyRegistry.keyGenVerifier();
        uint256 threshold = oprfKeyRegistry.threshold();
        uint256 numPeers = oprfKeyRegistry.numPeers();
        bytes32 domainTag = oprfKeyRegistry.domainTag();
        console.log("isContractReady:", isContractReady);
        console.log("amountAdmins:", amountAdmins);
        console.log("keyGenVerifier:", keyGenVerifier);
        console.log("threshold:", threshold);
        console.log("numPeers:", numPeers);
        console.logBytes32(domainTag);
        if (isContractReady) {
            console.log("PEERS:");
            for (uint256 i = 0; i < numPeers; ++i) {
                console.log(oprfKeyRegistry.peerAddresses(i));
            }
        }
        vm.stopBroadcast();
    }
}
