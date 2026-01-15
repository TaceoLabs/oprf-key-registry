// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BabyJubJub} from "../src/BabyJubJub.sol";
import {Contributions} from "./Contributions.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";
import {Types} from "../src/Types.sol";
import {Verifier as VerifierKeyGen13} from "../src/VerifierKeyGen13.sol";

contract OprfKeyRegistryKeyGenTest is Test {
    using Types for Types.BabyJubJubElement;

    uint256 public constant THRESHOLD = 2;
    uint256 public constant MAX_PEERS = 3;

    OprfKeyRegistry public oprfKeyRegistry;
    BabyJubJub public accumulator;
    VerifierKeyGen13 public verifierKeyGen;
    ERC1967Proxy public proxy;

    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address taceoAdmin = address(0x4);

    function setUp() public {
        accumulator = new BabyJubJub();
        verifierKeyGen = new VerifierKeyGen13();
        // Deploy implementation
        OprfKeyRegistry implementation = new OprfKeyRegistry();
        // Encode initializer call
        bytes memory initData = abi.encodeWithSelector(
            OprfKeyRegistry.initialize.selector, taceoAdmin, verifierKeyGen, accumulator, THRESHOLD, MAX_PEERS
        );
        // Deploy proxy
        proxy = new ERC1967Proxy(address(implementation), initData);
        oprfKeyRegistry = OprfKeyRegistry(address(proxy));

        // register participants for runs later
        address[] memory peerAddresses = new address[](3);
        peerAddresses[0] = alice;
        peerAddresses[1] = bob;
        peerAddresses[2] = carol;
        oprfKeyRegistry.registerOprfPeers(peerAddresses);
    }

    function testKeyGen() public {
        uint160 oprfKeyId = 42;
        vm.prank(taceoAdmin);
        vm.expectEmit(true, true, true, true);
        emit Types.SecretGenRound1(oprfKeyId, THRESHOLD);
        oprfKeyRegistry.initKeyGen(oprfKeyId);
        vm.stopPrank();

        // do round 1 contributions
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 1, 1, 0);
        oprfKeyRegistry.addRound1KeyGenContribution(oprfKeyId, Contributions.bobKeyGenRound1Contribution());
        vm.stopPrank();

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 0, 1, 0);
        oprfKeyRegistry.addRound1KeyGenContribution(oprfKeyId, Contributions.aliceKeyGenRound1Contribution());
        vm.stopPrank();

        vm.prank(carol);
        vm.expectEmit(true, true, true, true);
        emit Types.SecretGenRound2(oprfKeyId, 0);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 2, 1, 0);
        oprfKeyRegistry.addRound1KeyGenContribution(oprfKeyId, Contributions.carolKeyGenRound1Contribution());
        vm.stopPrank();

        // do round 2 contributions
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 1, 2, 0);
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.bobKeyGenRound2Contribution());
        vm.stopPrank();

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 0, 2, 0);
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.aliceKeyGenRound2Contribution());
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit Types.SecretGenRound3(oprfKeyId);
        vm.prank(carol);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 2, 2, 0);
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.carolKeyGenRound2Contribution());
        vm.stopPrank();

        // do round 3 contributions
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 0, 3, 0);
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 1, 3, 0);
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit Types.SecretGenFinalize(oprfKeyId, 0);
        vm.prank(carol);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 2, 3, 0);
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        // check that the computed key is correct
        Types.BabyJubJubElement memory oprfKey = oprfKeyRegistry.getOprfPublicKey(oprfKeyId);
        assertEq(oprfKey.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKey.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);

        Types.RegisteredOprfPublicKey memory oprfKeyAndEpoch = oprfKeyRegistry.getOprfPublicKeyAndEpoch(oprfKeyId);
        assertEq(oprfKey.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKey.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);
        assertEq(oprfKeyAndEpoch.key.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKeyAndEpoch.key.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);
        assertEq(oprfKeyAndEpoch.epoch, 0);
    }
}

