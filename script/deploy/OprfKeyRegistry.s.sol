// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OprfKeyRegistry} from "../../src/OprfKeyRegistry.sol";
import {OprfKeyRegistryV2} from "../../src/OprfKeyRegistryV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployOprfKeyRegistryScript is Script {
    OprfKeyRegistryV2 public oprfKeyRegistry;
    ERC1967Proxy public proxy;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address owner = msg.sender;
        address taceoAdminAddress = vm.envAddress("TACEO_ADMIN_ADDRESS");
        address keyGenVerifierAddress = vm.envAddress("KEY_GEN_VERIFIER_ADDRESS");
        uint256 threshold = vm.envUint("THRESHOLD");
        uint256 numPeers = vm.envUint("NUM_PEERS");
        string memory environmentTag = vm.envString("ENVIRONMENT");
        string memory projectDs = vm.envString("PROJECT_DS");

        console.log("using TACEO address:", taceoAdminAddress);
        console.log("using key-gen verifier address:", keyGenVerifierAddress);
        console.log("using threshold:", threshold);
        console.log("using numPeers:", numPeers);
        console.log("using environment:", environmentTag);
        console.log("using projectDs:", projectDs);

        // Deploy V2 implementation
        OprfKeyRegistryV2 implementation = new OprfKeyRegistryV2();
        // Encode initializer call (uses V1 initialize, inherited by V2)
        bytes memory initData = abi.encodeWithSelector(
            OprfKeyRegistry.initialize.selector, owner, taceoAdminAddress, keyGenVerifierAddress, threshold, numPeers
        );
        // Deploy proxy
        proxy = new ERC1967Proxy(address(implementation), initData);
        oprfKeyRegistry = OprfKeyRegistryV2(address(proxy));
        // Initialize V2-specific state
        oprfKeyRegistry.initializeV2(environmentTag, projectDs);

        vm.stopBroadcast();
        console.log("OprfKeyRegistryV2 implementation deployed to:", address(implementation));
        console.log("OprfKeyRegistryV2 proxy deployed to:", address(oprfKeyRegistry));
    }
}
