// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Contributions} from "./Contributions.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IOprfKeyRegistry} from "../src/IOprfKeyRegistry.sol";
import {IUnreleasedOprfKeyRegistryV2} from "../src/IUnreleasedOprfKeyRegistryV2.sol";
import {OprfKeyGen} from "../src/OprfKeyGen.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";
import {UnreleasedOprfKeyRegistryV2} from "../src/UnreleasedOprfKeyRegistryV2.sol";
import {Test} from "forge-std/Test.sol";
import {Verifier as VerifierKeyGen13} from "../src/VerifierKeyGen13.sol";

contract OprfKeyRegistryV3Mock is UnreleasedOprfKeyRegistryV2 {
    uint256 public newFeature;

    function version() public pure returns (string memory) {
        return "V3";
    }

    function setNewFeature(uint256 value) public {
        newFeature = value;
    }
}

contract OprfKeyRegistryUpgradeV2Test is Test {
    uint256 public constant THRESHOLD = 2;
    uint256 public constant MAX_PEERS = 3;

    UnreleasedOprfKeyRegistryV2 public oprfKeyRegistryV2;
    VerifierKeyGen13 public verifierKeyGen;
    ERC1967Proxy public proxy;

    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address taceoAdmin = address(0x4);
    address initOwner = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;

    function setUp() public {
        verifierKeyGen = new VerifierKeyGen13();
        UnreleasedOprfKeyRegistryV2 implementationV2 = new UnreleasedOprfKeyRegistryV2();
        bytes memory initData = abi.encodeWithSelector(
            OprfKeyRegistry.initialize.selector, initOwner, taceoAdmin, verifierKeyGen, THRESHOLD, MAX_PEERS
        );
        proxy = new ERC1967Proxy(address(implementationV2), initData);
        oprfKeyRegistryV2 = UnreleasedOprfKeyRegistryV2(address(proxy));

        address[] memory peerAddresses = new address[](3);
        peerAddresses[0] = alice;
        peerAddresses[1] = bob;
        peerAddresses[2] = carol;
        oprfKeyRegistryV2.registerOprfPeers(peerAddresses);
    }

    function testUpgradeFromV2ToV3Mock() public {
        uint160 oprfKeyId = 42;
        vm.prank(taceoAdmin);
        oprfKeyRegistryV2.initKeyGen(oprfKeyId);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IUnreleasedOprfKeyRegistryV2.KeyGenStuckReported(oprfKeyId, alice, OprfKeyGen.Round.ONE);
        oprfKeyRegistryV2.reportKeyGenStuck(oprfKeyId);

        OprfKeyRegistryV3Mock implementationV3 = new OprfKeyRegistryV3Mock();
        OprfKeyRegistry(address(proxy)).upgradeToAndCall(address(implementationV3), "");
        OprfKeyRegistryV3Mock oprfKeyRegistryV3 = OprfKeyRegistryV3Mock(address(proxy));

        assertEq(oprfKeyRegistryV3.owner(), initOwner);
        assertEq(oprfKeyRegistryV3.keygenAdmins(taceoAdmin), true);

        assertEq(oprfKeyRegistryV3.version(), "V3");
        oprfKeyRegistryV3.setNewFeature(7);
        assertEq(oprfKeyRegistryV3.newFeature(), 7);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IOprfKeyRegistry.WrongRound.selector, 4));
        oprfKeyRegistryV3.addRound1KeyGenContribution(oprfKeyId, Contributions.bobKeyGenRound1Contribution());
    }
}
