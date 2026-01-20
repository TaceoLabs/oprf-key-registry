// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {BabyJubJub} from "../src/BabyJubJub.sol";

contract BabyJubJubTest is Test {
    uint256 constant TWO_G_X = 10031262171927540148667355526369034398030886437092045105752248699557385197826;
    uint256 constant TWO_G_Y = 633281375905621697187330766174974863687049529291089048651929454608812697683;

    uint256 constant THREE_G_X = 2763488322167937039616325905516046217694264098671987087929565332380420898366;
    uint256 constant THREE_G_Y = 15305195750036305661220525648961313310481046260814497672243197092298550508693;

    function setUp() public {}

    function testIdentityPoint() public pure {
        assertTrue(BabyJubJub.isOnCurve(BabyJubJub.identity()));
        assertTrue(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(BabyJubJub.identity()));
    }

    function testGeneratorOnCurve() public pure {
        assertTrue(BabyJubJub.isOnCurve(BabyJubJub.generator()));
        assertTrue(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(BabyJubJub.generator()));
    }

    function doSingleLagrangeCheckDeg1(uint8[2] memory ins, uint256[3] memory should) private pure {
        uint256[] memory cast = new uint256[](2);
        uint256[] memory shouldResult = new uint256[](3);
        for (uint256 i = 0; i < 2; ++i) {
            cast[i] = uint256(ins[i]);
        }
        for (uint256 i = 0; i < 3; ++i) {
            shouldResult[i] = should[i];
        }
        uint256[] memory isResult = BabyJubJub.computeLagrangeCoefficiants(cast, 2, 3);
        assertEq(isResult, shouldResult);
    }

    function doSingleLagrangeCheckDeg2(uint8[3] memory ins, uint256[5] memory should) private pure {
        uint256[] memory cast = new uint256[](3);
        uint256[] memory shouldResult = new uint256[](5);
        for (uint256 i = 0; i < 3; ++i) {
            cast[i] = uint256(ins[i]);
        }
        for (uint256 i = 0; i < 5; ++i) {
            shouldResult[i] = should[i];
        }
        uint256[] memory isResult = BabyJubJub.computeLagrangeCoefficiants(cast, 3, 5);
        assertEq(isResult, shouldResult);
    }

    function testLagrangeCoeffsDegree2() public pure {
        doSingleLagrangeCheckDeg1(
            [0, 1], [2, 2736030358979909402780800718157159386076813972158567259200215660948447373040, 0]
        );
        doSingleLagrangeCheckDeg1(
            [0, 2],
            [
                1368015179489954701390400359078579693038406986079283629600107830474223686522,
                0,
                1368015179489954701390400359078579693038406986079283629600107830474223686520
            ]
        );
        doSingleLagrangeCheckDeg1(
            [1, 0], [2, 2736030358979909402780800718157159386076813972158567259200215660948447373040, 0]
        );
        doSingleLagrangeCheckDeg1(
            [1, 2], [0, 3, 2736030358979909402780800718157159386076813972158567259200215660948447373039]
        );
        doSingleLagrangeCheckDeg1(
            [2, 0],
            [
                1368015179489954701390400359078579693038406986079283629600107830474223686522,
                0,
                1368015179489954701390400359078579693038406986079283629600107830474223686520
            ]
        );
        doSingleLagrangeCheckDeg1(
            [2, 1], [0, 3, 2736030358979909402780800718157159386076813972158567259200215660948447373039]
        );
    }

    function testLagrangeCoeffsDegree3() public pure {
        doSingleLagrangeCheckDeg2(
            [0, 1, 2], [3, 2736030358979909402780800718157159386076813972158567259200215660948447373038, 1, 0, 0]
        );
        doSingleLagrangeCheckDeg2(
            [2, 1, 4], [0, 5, 2736030358979909402780800718157159386076813972158567259200215660948447373036, 0, 1]
        );
        doSingleLagrangeCheckDeg2(
            [1, 3, 0],
            [
                912010119659969800926933572719053128692271324052855753066738553649482457683,
                2736030358979909402780800718157159386076813972158567259200215660948447373039,
                0,
                1824020239319939601853867145438106257384542648105711506133477107298964915361,
                0
            ]
        );
        doSingleLagrangeCheckDeg2(
            [0, 4, 2],
            [
                342003794872488675347600089769644923259601746519820907400026957618555921632,
                0,
                684007589744977350695200179539289846519203493039641814800053915237111843259,
                0,
                1710018974362443376738000448848224616298008732599104537000134788092779608151
            ]
        );
    }

    function testAddIdentity() public pure {
        BabyJubJub.Affine memory p = BabyJubJub.add(BabyJubJub.identity(), BabyJubJub.generator());
        assertEq(p.x, BabyJubJub.GEN_X);
        assertEq(p.y, BabyJubJub.GEN_Y);
    }

    function testAddGeneratorToItself() public pure {
        BabyJubJub.Affine memory p = BabyJubJub.add(BabyJubJub.generator(), BabyJubJub.generator());
        assertTrue(BabyJubJub.isOnCurve(p));
        assertEq(p.x, TWO_G_X);
        assertEq(p.y, TWO_G_Y);
    }

    function testThreeTimes() public pure {
        // 2*Generator by adding generator to itself
        BabyJubJub.Affine memory twoG = BabyJubJub.add(BabyJubJub.generator(), BabyJubJub.generator());
        assertTrue(BabyJubJub.isOnCurve(twoG));
        assertTrue(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(twoG));

        // Add generator + 2*generator to get 3*generator
        BabyJubJub.Affine memory threeG = BabyJubJub.add(BabyJubJub.generator(), twoG);

        assertTrue(BabyJubJub.isOnCurve(threeG));
        assertTrue(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(threeG));

        // Result should be different from both G and 2G
        assertEq(threeG.x, THREE_G_X);
        assertEq(threeG.y, THREE_G_Y);
    }

    function testScalarMul() public pure {
        uint256 scalar0 = 0;
        BabyJubJub.Affine memory point0 = BabyJubJub.Affine({x: 0, y: 1});

        BabyJubJub.Affine memory pointKat = BabyJubJub.Affine({
            x: 5742303260101316936910431944725492393495696945462768307725717120096311286013,
            y: 7586271879783443543166246816922473256134012536615268324850965019989201082300
        });

        uint256 scalar_kat = 1242440491034235814403315695115999933845748848737909651389506153219096971846;
        uint256 neg_one = 2736030358979909402780800718157159386076813972158567259200215660948447373040;

        BabyJubJub.Affine memory kat0 = BabyJubJub.scalarMul(scalar0, point0);
        BabyJubJub.Affine memory kat1 = BabyJubJub.scalarMul(scalar_kat, point0);
        BabyJubJub.Affine memory kat2 = BabyJubJub.scalarMul(scalar0, pointKat);
        BabyJubJub.Affine memory kat3 = BabyJubJub.scalarMul(scalar_kat, pointKat);
        BabyJubJub.Affine memory kat4 = BabyJubJub.scalarMul(1, pointKat);
        BabyJubJub.Affine memory kat5 = BabyJubJub.scalarMul(2, pointKat);
        BabyJubJub.Affine memory kat6 = BabyJubJub.scalarMul(4, pointKat);
        BabyJubJub.Affine memory kat7 = BabyJubJub.scalarMul(42, pointKat);
        BabyJubJub.Affine memory kat8 = BabyJubJub.scalarMul(neg_one, pointKat);
        assertEq(kat0.x, 0);
        assertEq(kat0.y, 1);
        assertEq(kat1.x, 0);
        assertEq(kat1.y, 1);
        assertEq(kat2.x, 0);
        assertEq(kat2.y, 1);
        assertEq(kat3.x, 20956092296700245265278265822140773756208216231379934457160271877025655741709);
        assertEq(kat3.y, 9373184734215645832232006489640453756569166652467933657649907245660614875035);
        assertEq(kat4.x, 5742303260101316936910431944725492393495696945462768307725717120096311286013);
        assertEq(kat4.y, 7586271879783443543166246816922473256134012536615268324850965019989201082300);
        assertEq(kat5.x, 6131772964403619322402663037312951525771688328127170096563629070357285349398);
        assertEq(kat5.y, 1836188316779156006438769797518498112508509464186868448746605336786159216920);
        assertEq(kat6.x, 8375249795494070168540398175218576938320513942163892031567097533429205888430);
        assertEq(kat6.y, 18441278903475799996286506656206445898730701347337446493298174331394670509347);
        assertEq(kat7.x, 1833532272404155580546508629437702206187237625211957633811621844821648822989);
        assertEq(kat7.y, 21395320191466327696365123237974277902424108876271626253976471516775696177004);
        assertEq(kat8.x, 16145939611737958285335973800531782695052667454953266035972487066479497209604);
        assertEq(kat8.y, 7586271879783443543166246816922473256134012536615268324850965019989201082300);
    }

    function testCurveChecks() public pure {
        BabyJubJub.Affine memory notOnCurve = BabyJubJub.Affine({x: 42, y: 42});
        assertFalse(BabyJubJub.isOnCurve(notOnCurve));

        BabyJubJub.Affine memory zero = BabyJubJub.Affine({x: 0, y: 0});
        assertFalse(BabyJubJub.isOnCurve(zero));

        BabyJubJub.Affine memory twoTorsion =
            BabyJubJub.Affine({x: 0, y: 21888242871839275222246405745257275088548364400416034343698204186575808495616});
        assertTrue(BabyJubJub.isOnCurve(twoTorsion));
        assertFalse(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(twoTorsion));

        BabyJubJub.Affine memory kat1 = BabyJubJub.Affine({
            x: 8375249795494070168540398175218576938320513942163892031567097533429205888430,
            y: 18441278903475799996286506656206445898730701347337446493298174331394670509347
        });

        BabyJubJub.Affine memory kat2 = BabyJubJub.Affine({
            x: 1833532272404155580546508629437702206187237625211957633811621844821648822989,
            y: 21395320191466327696365123237974277902424108876271626253976471516775696177004
        });

        BabyJubJub.Affine memory kat3 = BabyJubJub.Affine({
            x: 16145939611737958285335973800531782695052667454953266035972487066479497209604,
            y: 7586271879783443543166246816922473256134012536615268324850965019989201082300
        });

        assertTrue(BabyJubJub.isOnCurve(kat1));
        assertTrue(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(kat1));

        assertTrue(BabyJubJub.isOnCurve(kat2));
        assertTrue(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(kat2));

        assertTrue(BabyJubJub.isOnCurve(kat3));
        assertTrue(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(kat3));
    }
}

