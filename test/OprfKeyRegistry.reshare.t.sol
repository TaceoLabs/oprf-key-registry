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
        reshare1();
    }

    function testReshare2() public {
        testReshare1();
        reshare2();
    }

    function reshare1() private {
        uint160 oprfKeyId = 42;
        uint128 generatedEpoch = 1;

        initReshare(oprfKeyId, generatedEpoch);

        reshare1Round1Contributions(oprfKeyId, generatedEpoch);
        reshare1Round2Contributions(oprfKeyId, generatedEpoch);
        reshare1Round3Contributions(oprfKeyId, generatedEpoch);

        // check that the computed key is correct
        checkGeneratedKey(oprfKeyId, generatedEpoch);
    }

    function reshare2() private {
        uint160 oprfKeyId = 42;
        uint128 generatedEpoch = 2;

        initReshare(oprfKeyId, generatedEpoch);

        reshare2Round1Contributions(oprfKeyId, generatedEpoch);
        reshare2Round2Contributions(oprfKeyId, generatedEpoch);
        reshare2Round3Contributions(oprfKeyId, generatedEpoch);

        // check that the computed key is correct
        checkGeneratedKey(oprfKeyId, generatedEpoch);
    }

    function testAbortAfterKeyGenMultipleTimes() public {
        uint160 oprfKeyId = 42;
        testKeyGen();
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        checkGeneratedKey(oprfKeyId, 0);
        // can still do a reshare 1 with correct epoch
        reshare1();
    }

    function testAbortAfterReshareMultipleTimes() public {
        uint160 oprfKeyId = 42;
        testReshare1();
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        checkGeneratedKey(oprfKeyId, 1);
        // can still do a reshare 2 with correct epoch
        reshare2();
    }

    function testAbortDuringKeyGenMultipleTimes() public {
        uint160 oprfKeyId = 42;
        initKeyGen(oprfKeyId);
        keyGenRound1Contributions(oprfKeyId);
        keyGenRound2Contributions(oprfKeyId);

        abortKeyGen(oprfKeyId);

        vm.prank(taceoAdmin);
        vm.expectRevert(abi.encodeWithSelector(OprfKeyRegistry.UnknownId.selector, 42));
        oprfKeyRegistry.abortKeyGen(oprfKeyId);
        vm.stopPrank();
    }

    function testAbortDuringKeyGenAndAddRound2Contribution() public {
        uint160 oprfKeyId = 42;
        initKeyGen(oprfKeyId);
        keyGenRound1Contributions(oprfKeyId);
        keyGenRound2Contributions(oprfKeyId);

        abortKeyGen(oprfKeyId);

        // we never create a key therefore we get unknown ID
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(OprfKeyRegistry.UnknownId.selector, 42));
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.carolReshare2Round2Contribution());
        vm.stopPrank();
        testReshare2();
    }

    function testAbortDuringKeyGenAndAddRound3Contribution() public {
        uint160 oprfKeyId = 42;
        initKeyGen(oprfKeyId);
        keyGenRound1Contributions(oprfKeyId);
        keyGenRound2Contributions(oprfKeyId);

        abortKeyGen(oprfKeyId);

        // we never create a key therefore we get unknown ID
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OprfKeyRegistry.UnknownId.selector, 42));
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();
        testReshare2();
    }

    function testAbortDuringKeyGenInitAgainAndAddRound2Contribution() public {
        uint160 oprfKeyId = 42;
        initKeyGen(oprfKeyId);
        keyGenRound1Contributions(oprfKeyId);
        keyGenRound2Contributions(oprfKeyId);

        abortKeyGen(oprfKeyId);
        initKeyGen(oprfKeyId);

        // we never create a key therefore we get unknown ID
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(OprfKeyRegistry.WrongRound.selector));
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.carolReshare2Round2Contribution());
        vm.stopPrank();
    }

    function testAbortDuringKeyGenInitAgainAndAddRound3Contribution() public {
        uint160 oprfKeyId = 42;
        initKeyGen(oprfKeyId);
        keyGenRound1Contributions(oprfKeyId);
        keyGenRound2Contributions(oprfKeyId);

        abortKeyGen(oprfKeyId);
        initKeyGen(oprfKeyId);

        // we never create a key therefore we get unknown ID
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OprfKeyRegistry.WrongRound.selector));
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();
    }

    function testAbortAfterReshareAndAddRound2Contribution() public {
        uint160 oprfKeyId = 42;
        testReshare1();
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(OprfKeyRegistry.WrongRound.selector));
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.carolReshare2Round2Contribution());
        vm.stopPrank();
        reshare2();
    }

    function testAbortAfterReshareAndAddRound3Contribution() public {
        uint160 oprfKeyId = 42;
        testReshare1();
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(OprfKeyRegistry.WrongRound.selector));
        oprfKeyRegistry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();
        reshare2();
    }

    function testAbortDuringReshareMultipleTimes() public {
        // make a normal key-gen for id 42;
        testKeyGen();
        uint128 generatedEpoch = 1;
        uint160 oprfKeyId = 42;

        initReshare(oprfKeyId, generatedEpoch);

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

        // abort during round 1
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        abortKeyGen(oprfKeyId);
        reshare1();
    }

    function testAbortReshareBeforeRound1() public {
        // make a normal key-gen for id 42;
        testKeyGen();
        uint160 oprfKeyId = 42;
        uint128 generatedEpoch = 1;

        initReshare(oprfKeyId, generatedEpoch);

        // abort before round 1
        abortKeyGen(oprfKeyId);

        // can still do a reshare
        reshare1();
    }

    function testAbortReshareDuringRound1() public {
        // make a normal key-gen for id 42;
        testKeyGen();
        uint128 generatedEpoch = 1;
        uint160 oprfKeyId = 42;

        initReshare(oprfKeyId, generatedEpoch);

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

        // abort during round 1
        abortKeyGen(oprfKeyId);
        reshare1();
    }

    function testAbortReshareBeforeRound2() public {
        // make a normal key-gen for id 42;
        testKeyGen();
        uint128 generatedEpoch = 1;
        uint160 oprfKeyId = 42;

        initReshare(oprfKeyId, generatedEpoch);
        reshare1Round1Contributions(oprfKeyId, generatedEpoch);
        abortKeyGen(oprfKeyId);
        reshare1();
    }

    function testAbortReshareDuringRound2() public {
        // make a normal key-gen for id 42;
        testKeyGen();
        uint128 generatedEpoch = 1;
        uint160 oprfKeyId = 42;

        initReshare(oprfKeyId, generatedEpoch);
        reshare1Round1Contributions(oprfKeyId, generatedEpoch);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Types.KeyGenConfirmation(oprfKeyId, 0, 2, generatedEpoch);
        oprfKeyRegistry.addRound2Contribution(oprfKeyId, Contributions.aliceReshare1Round2Contribution());
        vm.stopPrank();
        abortKeyGen(oprfKeyId);
        reshare1();
    }

    function testAbortReshareBeforeRound3() public {
        // make a normal key-gen for id 42;
        testKeyGen();
        uint128 generatedEpoch = 1;
        uint160 oprfKeyId = 42;

        initReshare(oprfKeyId, generatedEpoch);
        reshare1Round1Contributions(oprfKeyId, generatedEpoch);
        reshare1Round2Contributions(oprfKeyId, generatedEpoch);
        abortKeyGen(oprfKeyId);
        reshare1();
    }

    function testAbortReshareDuringRound3() public {
        // make a normal key-gen for id 42;
        testKeyGen();
        uint128 generatedEpoch = 1;
        uint160 oprfKeyId = 42;

        initReshare(oprfKeyId, generatedEpoch);
        reshare1Round1Contributions(oprfKeyId, generatedEpoch);
        reshare1Round2Contributions(oprfKeyId, generatedEpoch);

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
        abortKeyGen(oprfKeyId);
        reshare1();
    }

    function testAbortAfterReshare() public {
        uint160 oprfKeyId = 42;
        testReshare1();
        abortKeyGen(oprfKeyId);
    }

    function initReshare(uint160 oprfKeyId, uint128 generatedEpoch) private {
        vm.prank(taceoAdmin);
        vm.expectEmit(true, true, true, true);
        emit Types.ReshareRound1(oprfKeyId, THRESHOLD, generatedEpoch);
        oprfKeyRegistry.initReshare(oprfKeyId);
        vm.stopPrank();
    }

    function reshare1Round1Contributions(uint160 oprfKeyId, uint128 generatedEpoch) private {
        // carol is a consumer here
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
    }

    function reshare1Round2Contributions(uint160 oprfKeyId, uint128 generatedEpoch) private {
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
    }

    function reshare1Round3Contributions(uint160 oprfKeyId, uint128 generatedEpoch) private {
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
    }

    function reshare2Round1Contributions(uint160 oprfKeyId, uint128 generatedEpoch) private {
        // alice is a consumer here
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
    }

    function reshare2Round2Contributions(uint160 oprfKeyId, uint128 generatedEpoch) private {
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
    }

    function reshare2Round3Contributions(uint160 oprfKeyId, uint128 generatedEpoch) private {
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
    }
}
