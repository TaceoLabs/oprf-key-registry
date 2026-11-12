// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BabyJubJub} from "@taceo/babyjubjub/BabyJubJub.sol";
import {Contributions} from "./Contributions.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OprfKeyGen} from "../src/OprfKeyGen.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";
import {OprfKeyRegistryV2} from "../src/OprfKeyRegistryV2.sol";
import {Test} from "forge-std/Test.sol";
import {Verifier as VerifierKeyGen13} from "../src/VerifierKeyGen13.sol";

contract OprfKeyRegistryKeyGenGasTest is Test {
    uint256 public constant THRESHOLD = 2;
    uint256 public constant MAX_PEERS = 3;
    uint160 public constant OPRF_KEY_ID = 42;

    OprfKeyRegistryV2 public oprfKeyRegistry;

    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address taceoAdmin = address(0x4);
    address initOwner = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496; // the default addr of this test contract

    function setUp() public {
        VerifierKeyGen13 verifierKeyGen = new VerifierKeyGen13();
        OprfKeyRegistryV2 implementation = new OprfKeyRegistryV2();
        bytes memory initData = abi.encodeWithSelector(
            OprfKeyRegistry.initialize.selector, initOwner, taceoAdmin, verifierKeyGen, THRESHOLD, MAX_PEERS
        );
        oprfKeyRegistry = OprfKeyRegistryV2(address(new ERC1967Proxy(address(implementation), initData)));

        address[] memory peerAddresses = new address[](3);
        peerAddresses[0] = alice;
        peerAddresses[1] = bob;
        peerAddresses[2] = carol;
        oprfKeyRegistry.registerOprfPeers(peerAddresses);
    }

    function testGasKeyGen() public {
        vm.prank(taceoAdmin);
        oprfKeyRegistry.initKeyGen(OPRF_KEY_ID);
        vm.snapshotGasLastCall("initKeyGen");

        OprfKeyGen.Round1Contribution memory r1;
        r1 = Contributions.bobKeyGenRound1Contribution();
        vm.prank(bob);
        oprfKeyRegistry.addRound1KeyGenContribution(OPRF_KEY_ID, r1);
        vm.snapshotGasLastCall("round1_bob");

        r1 = Contributions.aliceKeyGenRound1Contribution();
        vm.prank(alice);
        oprfKeyRegistry.addRound1KeyGenContribution(OPRF_KEY_ID, r1);
        vm.snapshotGasLastCall("round1_alice");

        r1 = Contributions.carolKeyGenRound1Contribution();
        vm.prank(carol);
        oprfKeyRegistry.addRound1KeyGenContribution(OPRF_KEY_ID, r1);
        vm.snapshotGasLastCall("round1_carol_last");

        OprfKeyGen.Round2Contribution memory r2;
        r2 = Contributions.bobKeyGenRound2Contribution();
        vm.prank(bob);
        oprfKeyRegistry.addRound2Contribution(OPRF_KEY_ID, r2);
        vm.snapshotGasLastCall("round2_bob");

        r2 = Contributions.aliceKeyGenRound2Contribution();
        vm.prank(alice);
        oprfKeyRegistry.addRound2Contribution(OPRF_KEY_ID, r2);
        vm.snapshotGasLastCall("round2_alice");

        r2 = Contributions.carolKeyGenRound2Contribution();
        vm.prank(carol);
        oprfKeyRegistry.addRound2Contribution(OPRF_KEY_ID, r2);
        vm.snapshotGasLastCall("round2_carol_last");

        vm.prank(alice);
        oprfKeyRegistry.addRound3Contribution(OPRF_KEY_ID);
        vm.snapshotGasLastCall("round3_alice");

        vm.prank(bob);
        oprfKeyRegistry.addRound3Contribution(OPRF_KEY_ID);
        vm.snapshotGasLastCall("round3_bob");

        vm.prank(carol);
        oprfKeyRegistry.addRound3Contribution(OPRF_KEY_ID);
        vm.snapshotGasLastCall("round3_carol_last");

        BabyJubJub.Affine memory oprfKey = oprfKeyRegistry.getOprfPublicKey(OPRF_KEY_ID);
        assertEq(oprfKey.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKey.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);
    }
}
