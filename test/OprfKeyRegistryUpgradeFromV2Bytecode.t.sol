// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Contributions} from "./Contributions.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IOprfKeyRegistry} from "../src/IOprfKeyRegistry.sol";
import {OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";
import {OprfKeyRegistryV2} from "../src/OprfKeyRegistryV2.sol";
import {OprfKeyRegistryReshareTest} from "./OprfKeyRegistry.reshare.t.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice Upgrades a proxy running the *released* v2.0.0 bytecode (test/fixtures, built from `main` with the
/// BabyJubJub library linked to `LIB`) to the current implementation and checks that state written by the old
/// storage layout (registered keys, epochs, share commitments, deleted markers) is read correctly afterwards.
contract OprfKeyRegistryUpgradeFromV2BytecodeTest is OprfKeyRegistryReshareTest {
    address constant LIB = 0x0000000000000000000000000000000000Bab1E5;
    uint160 constant KEY = 42;

    function _deployOldProxy() private {
        vm.etch(LIB, vm.getDeployedCode("BabyJubJub.sol:BabyJubJub"));
        bytes memory code = vm.parseBytes(vm.readFile("test/fixtures/OprfKeyRegistryV2_v2.0.0.bin"));
        address impl;
        assembly ("memory-safe") {
            impl := create(0, add(code, 0x20), mload(code))
        }
        require(impl != address(0), "old impl deployment failed");

        bytes memory initData = abi.encodeWithSelector(
            OprfKeyRegistry.initialize.selector, initOwner, taceoAdmin, verifierKeyGen, THRESHOLD, MAX_PEERS
        );
        proxy = new ERC1967Proxy(impl, initData);
        oprfKeyRegistry = OprfKeyRegistry(address(proxy));

        address[] memory peers = new address[](3);
        peers[0] = alice;
        peers[1] = bob;
        peers[2] = carol;
        oprfKeyRegistry.registerOprfPeers(peers);
    }

    function _upgradeToCurrent() private {
        OprfKeyRegistryV2 impl = new OprfKeyRegistryV2();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(impl), "");
    }

    function testUpgradeAfterKeyGenThenReshareTwice() public {
        _deployOldProxy();
        testKeyGen();
        _upgradeToCurrent();
        checkGeneratedKey(KEY, 0);

        initReshare(KEY, 1);
        reshare1Round1Contributions(KEY, 1);
        reshare1Round2Contributions(KEY, 1);
        reshare1Round3Contributions(KEY, 1);
        checkGeneratedKey(KEY, 1);

        initReshare(KEY, 2);
        reshare2Round1Contributions(KEY, 2);
        reshare2Round2Contributions(KEY, 2);
        reshare2Round3Contributions(KEY, 2);
        checkGeneratedKey(KEY, 2);
    }

    function testUpgradeAfterReshareThenReshare() public {
        _deployOldProxy();
        testKeyGen();
        initReshare(KEY, 1);
        reshare1Round1Contributions(KEY, 1);
        reshare1Round2Contributions(KEY, 1);
        reshare1Round3Contributions(KEY, 1);
        checkGeneratedKey(KEY, 1);

        _upgradeToCurrent();
        checkGeneratedKey(KEY, 1);

        initReshare(KEY, 2);
        reshare2Round1Contributions(KEY, 2);
        reshare2Round2Contributions(KEY, 2);
        reshare2Round3Contributions(KEY, 2);
        checkGeneratedKey(KEY, 2);
    }

    function testUpgradeMidReshareNeedsAbort() public {
        _deployOldProxy();
        testKeyGen();
        initReshare(KEY, 1);
        // round 1 completes under the old code, the process is in round 2
        reshare1Round1Contributions(KEY, 1);

        _upgradeToCurrent();

        // the round 1 data of the old run is not visible to the new code: round 2 must be rejected
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOprfKeyRegistry.BadContribution.selector));
        oprfKeyRegistry.addRound2Contribution(KEY, Contributions.aliceReshare1Round2Contribution());
        vm.stopPrank();

        // the admin aborts and restarts the reshare, which then runs to completion on the new code
        abortKeyGen(KEY);
        checkGeneratedKey(KEY, 0);
        initReshare(KEY, 1);
        reshare1Round1Contributions(KEY, 1);
        reshare1Round2Contributions(KEY, 1);
        reshare1Round3Contributions(KEY, 1);
        checkGeneratedKey(KEY, 1);
    }

    function testUpgradeKeepsDeletedKey() public {
        _deployOldProxy();
        testKeyGen();
        deleteOprfKey(KEY);

        _upgradeToCurrent();
        checkGeneratedIsDeleted(KEY);

        vm.prank(taceoAdmin);
        vm.expectRevert(abi.encodeWithSelector(IOprfKeyRegistry.DeletedId.selector, KEY));
        oprfKeyRegistry.initKeyGen(KEY);
        vm.stopPrank();
    }
}
