// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Contributions} from "./Contributions.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IOprfKeyRegistry} from "../src/IOprfKeyRegistry.sol";
import {IOprfKeyRegistryV2} from "../src/IOprfKeyRegistryV2.sol";
import {OprfKeyGen} from "../src/OprfKeyGen.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";
import {OprfKeyRegistryV2} from "../src/OprfKeyRegistryV2.sol";
import {Test} from "forge-std/Test.sol";
import {Verifier as VerifierKeyGen13} from "../src/VerifierKeyGen13.sol";

contract OprfKeyRegistryV2Test is Test {
    uint256 public constant THRESHOLD = 2;
    uint256 public constant MAX_PEERS = 3;

    OprfKeyRegistryV2 public oprfKeyRegistry;
    VerifierKeyGen13 public verifierKeyGen;
    ERC1967Proxy public proxy;

    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address taceoAdmin = address(0x4);
    address initOwner = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;

    function setUp() public {
        verifierKeyGen = new VerifierKeyGen13();
        OprfKeyRegistryV2 implementation = new OprfKeyRegistryV2();
        bytes memory initData = abi.encodeWithSelector(
            OprfKeyRegistry.initialize.selector, initOwner, taceoAdmin, verifierKeyGen, THRESHOLD, MAX_PEERS
        );
        proxy = new ERC1967Proxy(address(implementation), initData);
        oprfKeyRegistry = OprfKeyRegistryV2(address(proxy));

        address[] memory peerAddresses = new address[](3);
        peerAddresses[0] = alice;
        peerAddresses[1] = bob;
        peerAddresses[2] = carol;
        oprfKeyRegistry.registerOprfPeers(peerAddresses);
    }

    function testReportKeyGenStuckFromParticipant() public {
        uint160 oprfKeyId = 42;

        vm.prank(taceoAdmin);
        oprfKeyRegistry.initKeyGen(oprfKeyId);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IOprfKeyRegistryV2.KeyGenStuckReported(oprfKeyId, alice, OprfKeyGen.Round.ONE);
        oprfKeyRegistry.reportKeyGenStuck(oprfKeyId);

        // Bob tries to add his contribution but the round is stuck
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IOprfKeyRegistry.WrongRound.selector, 4));
        oprfKeyRegistry.addRound1KeyGenContribution(oprfKeyId, Contributions.bobKeyGenRound1Contribution());
    }

    function testReportKeyGenStuckRevertNonParticipant() public {
        uint160 oprfKeyId = 42;

        vm.prank(taceoAdmin);
        oprfKeyRegistry.initKeyGen(oprfKeyId);

        // Non-participant tries to report stuck
        vm.prank(address(0xdeadbeef));
        vm.expectRevert(abi.encodeWithSelector(IOprfKeyRegistry.NotAParticipant.selector));
        oprfKeyRegistry.reportKeyGenStuck(oprfKeyId);
    }

    function testReportKeyGenStuckRevertUnknownId() public {
        uint160 oprfKeyId = 42;

        vm.prank(alice);

        // Key gen never started
        vm.expectRevert(abi.encodeWithSelector(IOprfKeyRegistry.UnknownId.selector, oprfKeyId));
        oprfKeyRegistry.reportKeyGenStuck(oprfKeyId);
    }

    function testReportKeyGenStuckRevertWhenAlreadyStuck() public {
        uint160 oprfKeyId = 42;

        vm.prank(taceoAdmin);
        oprfKeyRegistry.initKeyGen(oprfKeyId);

        vm.prank(alice);
        oprfKeyRegistry.reportKeyGenStuck(oprfKeyId);

        // Bob tries to report stuck but the round is already stuck
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IOprfKeyRegistry.WrongRound.selector, 4));
        oprfKeyRegistry.reportKeyGenStuck(oprfKeyId);
    }

    function testGetPeerAddresses() public view {
        address[] memory peers = oprfKeyRegistry.getPeerAddresses();
        assertEq(peers.length, 3);
        assertEq(peers[0], alice);
        assertEq(peers[1], bob);
        assertEq(peers[2], carol);
    }

    function testIsParticipant() public view {
        assertTrue(oprfKeyRegistry.isParticipant(alice));
        assertFalse(oprfKeyRegistry.isParticipant(address(0xdeadbeef)));
    }
}
