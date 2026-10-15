// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract PrintInformationScript is Script {
    OprfKeyRegistry public oprfKeyRegistry;

    function setUp() public {
        oprfKeyRegistry = OprfKeyRegistry(vm.envAddress("OPRF_KEY_REGISTRY_PROXY"));
    }

    function run() external {
        vm.startBroadcast();
        bool isContractReady = oprfKeyRegistry.isContractReady();
        uint256 amountAdmins = oprfKeyRegistry.amountKeygenAdmins();
        address keyGenVerifier = oprfKeyRegistry.keyGenVerifier();
        address owner = oprfKeyRegistry.owner();
        uint256 threshold = oprfKeyRegistry.threshold();
        uint256 numPeers = oprfKeyRegistry.numPeers();
        address implementation =
            address(uint160(uint256(vm.load(address(oprfKeyRegistry), ERC1967Utils.IMPLEMENTATION_SLOT))));
        console.log("implementation:", implementation);
        console.log("isContractReady:", isContractReady);
        console.log("amountAdmins:", amountAdmins);
        console.log("keyGenVerifier:", keyGenVerifier);
        console.log("owner:", owner);
        console.log("threshold:", threshold);
        console.log("numPeers:", numPeers);
        if (isContractReady) {
            console.log("PEERS:");
            for (uint256 i = 0; i < numPeers; ++i) {
                console.log(oprfKeyRegistry.peerAddresses(i));
            }
        }
        vm.stopBroadcast();
    }
}
