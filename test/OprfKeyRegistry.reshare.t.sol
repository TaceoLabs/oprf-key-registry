// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BabyJubJub} from "../src/BabyJubJub.sol";
import {Contributions} from "./Contributions.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";
import {Types} from "../src/Types.sol";
import {OprfKeyRegistryKeyGenTest} from "./OprfKeyRegistry.keygen.t.sol";
import {Verifier as VerifierKeyGen13} from "../src/VerifierKeyGen13.sol";

contract OprfKeyRegistryReshareTest is Test, OprfKeyRegistryKeyGenTest {
    using Types for Types.BabyJubJubElement;

    function testReshare1() public {
        testKeyGen();
        uint160 oprfKeyId = 42;
        uint128 generatedEpoch = 1;

        vm.prank(taceoAdmin);
        vm.expectEmit(true, true, true, true);
        emit Types.ReshareRound1(oprfKeyId, THRESHOLD, generatedEpoch);
        oprfKeyRegistry.initReshare(oprfKeyId);
        vm.stopPrank();

        // carol is a consumer here
        // do round 1 contributions
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 1, 1, generatedEpoch);
        oprfKeyRegistry.addRound1ReshareContribution(oprfKeyId, Contributions.bobReshare1Round1Contribution());
        vm.stopPrank();

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 0, 1, generatedEpoch);
        oprfKeyRegistry.addRound1ReshareContribution(oprfKeyId, Contributions.aliceReshare1Round1Contribution());
        vm.stopPrank();

        vm.prank(carol);
        vm.expectEmit(true, true, true, true);
        emit Types.SecretGenRound2(oprfKeyId, generatedEpoch);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 2, 1, generatedEpoch);
        oprfKeyRegistry.addRound1ReshareContribution(oprfKeyId, Contributions.carolReshare1Round1Contribution());
        vm.stopPrank();

        // do round 2 contributions
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 0, 2, generatedEpoch);
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.aliceReshare1Round2Contribution());
        vm.stopPrank();

        vm.prank(bob);
        uint256[] memory lagrange_should = new uint256[](3);
        lagrange_should[0] = Contributions.LAGRANGE_RESHARE1_0;
        lagrange_should[1] = Contributions.LAGRANGE_RESHARE1_1;
        lagrange_should[2] = 0;
        vm.expectEmit(true, true, true, true);
        emit Types.ReshareRound3(oprfKeyId, lagrange_should, generatedEpoch);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 1, 2, generatedEpoch);
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.bobReshare1Round2Contribution());
        vm.stopPrank();

        // do round 3 contributions
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 0, 3, generatedEpoch);
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 1, 3, generatedEpoch);
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        // check that we are still in epoch 0
        Types.RegisteredOprfPublicKey memory oprfKeyAndEpochKeyGen = oprfKeyRegistry.getOprfPublicKeyAndEpoch(oprfKeyId);
        assertEq(oprfKeyAndEpochKeyGen.key.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKeyAndEpochKeyGen.key.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);
        assertEq(oprfKeyAndEpochKeyGen.epoch, 0);

        // last contribution
        vm.expectEmit(true, true, true, true);
        emit Types.SecretGenFinalize(oprfKeyId, generatedEpoch);
        vm.prank(carol);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 2, 3, generatedEpoch);
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        // check that the computed key is correct
        Types.BabyJubJubElement memory oprfKey = oprfKeyRegistry.getOprfPublicKey(oprfKeyId);
        assertEq(oprfKey.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKey.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);

        Types.RegisteredOprfPublicKey memory oprfKeyAndEpoch = oprfKeyRegistry.getOprfPublicKeyAndEpoch(oprfKeyId);
        assertEq(oprfKeyAndEpoch.key.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKeyAndEpoch.key.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);
        assertEq(oprfKeyAndEpoch.epoch, generatedEpoch);
    }

    function testReshare2() public {
        testReshare1();
        uint160 oprfKeyId = 42;
        uint128 generatedEpoch = 2;

        vm.prank(taceoAdmin);
        vm.expectEmit(true, true, true, true);
        emit Types.ReshareRound1(oprfKeyId, THRESHOLD, generatedEpoch);
        oprfKeyRegistry.initReshare(oprfKeyId);
        vm.stopPrank();

        // alice is a consumer here
        // do round 1 contributions
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 1, 1, generatedEpoch);
        oprfKeyRegistry.addRound1ReshareContribution(oprfKeyId, Contributions.bobReshare2Round1Contribution());
        vm.stopPrank();

        vm.prank(carol);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 2, 1, generatedEpoch);
        oprfKeyRegistry.addRound1ReshareContribution(oprfKeyId, Contributions.carolReshare2Round1Contribution());
        vm.stopPrank();

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Types.SecretGenRound2(oprfKeyId, generatedEpoch);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 0, 1, generatedEpoch);
        oprfKeyRegistry.addRound1ReshareContribution(oprfKeyId, Contributions.aliceReshare2Round1Contribution());
        vm.stopPrank();

        // do round 2 contributions
        vm.prank(carol);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 2, 2, generatedEpoch);
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.carolReshare2Round2Contribution());
        vm.stopPrank();

        vm.prank(bob);
        uint256[] memory lagrange_should = new uint256[](3);
        lagrange_should[0] = 0;
        lagrange_should[1] = Contributions.LAGRANGE_RESHARE2_0;
        lagrange_should[2] = Contributions.LAGRANGE_RESHARE2_1;
        vm.expectEmit(true, true, true, true);
        emit Types.ReshareRound3(oprfKeyId, lagrange_should, generatedEpoch);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 1, 2, generatedEpoch);
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.bobReshare2Round2Contribution());
        vm.stopPrank();

        // do round 3 contributions
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 0, 3, generatedEpoch);
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 1, 3, generatedEpoch);
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        // check that we are still in epoch 0
        Types.RegisteredOprfPublicKey memory oprfKeyAndEpochKeyGen = oprfKeyRegistry.getOprfPublicKeyAndEpoch(oprfKeyId);
        assertEq(oprfKeyAndEpochKeyGen.key.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKeyAndEpochKeyGen.key.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);
        assertEq(oprfKeyAndEpochKeyGen.epoch, generatedEpoch - 1);

        // last contribution
        vm.expectEmit(true, true, true, true);
        emit Types.SecretGenFinalize(oprfKeyId, generatedEpoch);
        vm.prank(carol);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 2, 3, generatedEpoch);
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        // check that the computed key is correct
        Types.BabyJubJubElement memory oprfKey = oprfKeyRegistry.getOprfPublicKey(oprfKeyId);
        assertEq(oprfKey.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKey.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);

        Types.RegisteredOprfPublicKey memory oprfKeyAndEpoch = oprfKeyRegistry.getOprfPublicKeyAndEpoch(oprfKeyId);
        assertEq(oprfKeyAndEpoch.key.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(oprfKeyAndEpoch.key.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);
        assertEq(oprfKeyAndEpoch.epoch, generatedEpoch);
    }
}

