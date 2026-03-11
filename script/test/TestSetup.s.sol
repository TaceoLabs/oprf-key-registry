// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OprfKeyRegistry} from "../../src/OprfKeyRegistry.sol";
import {OprfKeyRegistryV2} from "../../src/OprfKeyRegistryV2.sol";
import {Verifier as VerifierKeyGen13} from "../../src/VerifierKeyGen13.sol";
import {Verifier as VerifierKeyGen25} from "../../src/VerifierKeyGen25.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestSetupScript is Script {
    OprfKeyRegistryV2 public oprfKeyRegistry;
    ERC1967Proxy public proxy;

    function setUp() public {}

    function deployGroth16VerifierKeyGen(uint256 threshold, uint256 numPeers) public returns (address) {
        if (threshold == 2 && numPeers == 3) {
            VerifierKeyGen13 verifier = new VerifierKeyGen13();
            console.log("VerifierKeyGen deployed to:", address(verifier));
            return address(verifier);
        } else if (threshold == 3 && numPeers == 5) {
            VerifierKeyGen25 verifier = new VerifierKeyGen25();
            console.log("VerifierKeyGen deployed to:", address(verifier));
            return address(verifier);
        } else {
            revert("Unsupported threshold and numPeers combination");
        }
    }

    function run() public {
        vm.startBroadcast();

        uint256 threshold = vm.envUint("THRESHOLD");
        uint256 numPeers = vm.envUint("NUM_PEERS");
        address keyGenVerifierAddress = deployGroth16VerifierKeyGen(threshold, numPeers);
        address taceoAdminAddress = vm.envAddress("TACEO_ADMIN_ADDRESS");
        address owner = msg.sender;
        string memory environmentTag = vm.envString("ENVIRONMENT");
        string memory projectDs = vm.envString("PROJECT_DS");

        address[] memory participants = vm.envAddress("PARTICIPANT_ADDRESSES", ",");
        for (uint256 i = 0; i < participants.length; i++) {
            console.log("Registering participant address:", participants[i]);
        }

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

        oprfKeyRegistry.registerOprfPeers(participants);

        // check that contract is ready
        assert(oprfKeyRegistry.isContractReady());
        vm.stopBroadcast();

        console.log("OprfKeyRegistryV2 deployed to:", address(oprfKeyRegistry));
    }
}
