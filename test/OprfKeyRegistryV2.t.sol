// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BabyJubJub} from "@taceo/babyjubjub/BabyJubJub.sol";
import {Contributions} from "./Contributions.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IOprfKeyRegistryMpc, OprfKeyRegistry} from "../src/OprfKeyRegistry.sol";
import {OprfKeyRegistryV2} from "../src/OprfKeyRegistryV2.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Test} from "forge-std/Test.sol";
import {Verifier as VerifierKeyGen13} from "../src/VerifierKeyGen13.sol";

contract OprfKeyRegistryV2Test is Test {
    using BabyJubJub for BabyJubJub.Affine;

    uint16 public constant THRESHOLD = 2;
    uint16 public constant MAX_PEERS = 3;

    string constant ENV = "prod";
    string constant PROJECT_DS = "myproject";

    OprfKeyRegistry public oprfKeyRegistry;
    VerifierKeyGen13 public verifierKeyGen;
    ERC1967Proxy public proxy;

    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address taceoAdmin = address(0x4);
    address notOwner = address(0x5);
    address initOwner = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496; // default forge test contract address

    function setUp() public {
        verifierKeyGen = new VerifierKeyGen13();
        OprfKeyRegistry implementation = new OprfKeyRegistry();
        bytes memory initData = abi.encodeWithSelector(
            OprfKeyRegistry.initialize.selector, initOwner, taceoAdmin, verifierKeyGen, THRESHOLD, MAX_PEERS
        );
        proxy = new ERC1967Proxy(address(implementation), initData);
        oprfKeyRegistry = OprfKeyRegistry(address(proxy));

        address[] memory peerAddresses = new address[](3);
        peerAddresses[0] = alice;
        peerAddresses[1] = bob;
        peerAddresses[2] = carol;
        oprfKeyRegistry.registerOprfPeers(peerAddresses);
    }

    // ============================================================
    // Helpers
    // ============================================================

    /// @dev Upgrades the proxy to a fresh V2 implementation (no initialization).
    function _upgradeToV2() internal returns (OprfKeyRegistryV2) {
        OprfKeyRegistryV2 implementationV2 = new OprfKeyRegistryV2();
        OprfKeyRegistry(address(proxy)).upgradeToAndCall(address(implementationV2), "");
        return OprfKeyRegistryV2(address(proxy));
    }

    /// @dev Upgrades the proxy to V2 and calls initializeV2 atomically.
    function _upgradeAndInitV2() internal returns (OprfKeyRegistryV2) {
        OprfKeyRegistryV2 implementationV2 = new OprfKeyRegistryV2();
        bytes memory initV2Data = abi.encodeWithSelector(OprfKeyRegistryV2.initializeV2.selector, ENV, PROJECT_DS);
        OprfKeyRegistry(address(proxy)).upgradeToAndCall(address(implementationV2), initV2Data);
        return OprfKeyRegistryV2(address(proxy));
    }

    function _expectedDomainTag(string memory envStr, string memory project) internal pure returns (bytes32) {
        return keccak256(bytes(string.concat(envStr, "-", project, "-TACEO:OPRF")));
    }

    function _runFullKeyGen(OprfKeyRegistry registry, uint160 oprfKeyId) internal {
        vm.prank(taceoAdmin);
        registry.initKeyGen(oprfKeyId);
        vm.stopPrank();

        vm.prank(bob);
        registry.addRound1KeyGenContribution(oprfKeyId, Contributions.bobKeyGenRound1Contribution());
        vm.stopPrank();

        vm.prank(alice);
        registry.addRound1KeyGenContribution(oprfKeyId, Contributions.aliceKeyGenRound1Contribution());
        vm.stopPrank();

        vm.prank(carol);
        registry.addRound1KeyGenContribution(oprfKeyId, Contributions.carolKeyGenRound1Contribution());
        vm.stopPrank();

        vm.prank(bob);
        registry.addRound2Contribution(oprfKeyId, Contributions.bobKeyGenRound2Contribution());
        vm.stopPrank();

        vm.prank(alice);
        registry.addRound2Contribution(oprfKeyId, Contributions.aliceKeyGenRound2Contribution());
        vm.stopPrank();

        vm.prank(carol);
        registry.addRound2Contribution(oprfKeyId, Contributions.carolKeyGenRound2Contribution());
        vm.stopPrank();

        vm.prank(alice);
        registry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        vm.prank(bob);
        registry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();

        vm.prank(carol);
        registry.addRound3Contribution(oprfKeyId);
        vm.stopPrank();
    }

    // ============================================================
    // Upgrade
    // ============================================================

    function testUpgradeToV2PreservesStorage() public {
        _runFullKeyGen(oprfKeyRegistry, 42);
        BabyJubJub.Affine memory keyBefore = oprfKeyRegistry.getOprfPublicKey(42);

        OprfKeyRegistryV2 v2 = _upgradeToV2();

        BabyJubJub.Affine memory keyAfter = v2.getOprfPublicKey(42);
        assertEq(keyAfter.x, keyBefore.x);
        assertEq(keyAfter.y, keyBefore.y);
        assertEq(keyAfter.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(keyAfter.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);
    }

    function testUpgradeToV2DomainTagIsZeroUntilInitialized() public {
        OprfKeyRegistryV2 v2 = _upgradeToV2();
        assertEq(v2.domainTag(), bytes32(0));
    }

    // ============================================================
    // initializeV2
    // ============================================================

    function testInitializeV2SetsDomainTag() public {
        OprfKeyRegistryV2 v2 = _upgradeToV2();
        bytes32 expected = _expectedDomainTag(ENV, PROJECT_DS);

        vm.expectEmit(true, true, false, false);
        emit OprfKeyRegistryV2.DomainTagUpdated(bytes32(0), expected);
        v2.initializeV2(ENV, PROJECT_DS);

        assertEq(v2.domainTag(), expected);
    }

    function testInitializeV2RevertsOnSecondCall() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        v2.initializeV2(ENV, PROJECT_DS);
    }

    function testInitializeV2RevertsForNonOwner() public {
        OprfKeyRegistryV2 v2 = _upgradeToV2();

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, notOwner));
        v2.initializeV2(ENV, PROJECT_DS);
        vm.stopPrank();
    }

    function testUpgradeAndInitializeAtomically() public {
        bytes32 expected = _expectedDomainTag(ENV, PROJECT_DS);
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();
        assertEq(v2.domainTag(), expected);
    }

    // ============================================================
    // updateDomainTag
    // ============================================================

    function testUpdateDomainTag() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();
        bytes32 oldTag = v2.domainTag();
        bytes32 newExpected = _expectedDomainTag("stage", "otherproject");

        vm.expectEmit(true, true, false, false);
        emit OprfKeyRegistryV2.DomainTagUpdated(oldTag, newExpected);
        v2.updateDomainTag("stage", "otherproject");

        assertEq(v2.domainTag(), newExpected);
    }

    function testUpdateDomainTagRevertsForNonOwner() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, notOwner));
        v2.updateDomainTag("stage", "otherproject");
        vm.stopPrank();
    }

    // ============================================================
    // Domain tag computation per environment
    // ============================================================

    function testDomainTagComputationTest() public {
        OprfKeyRegistryV2 v2 = _upgradeToV2();
        v2.initializeV2("test", "taceo");
        assertEq(v2.domainTag(), keccak256(bytes("test-taceo-TACEO:OPRF")));
    }

    function testDomainTagComputationStage() public {
        OprfKeyRegistryV2 v2 = _upgradeToV2();
        v2.initializeV2("stage", "taceo");
        assertEq(v2.domainTag(), keccak256(bytes("stage-taceo-TACEO:OPRF")));
    }

    function testDomainTagComputationProd() public {
        OprfKeyRegistryV2 v2 = _upgradeToV2();
        v2.initializeV2("prod", "taceo");
        assertEq(v2.domainTag(), keccak256(bytes("prod-taceo-TACEO:OPRF")));
    }

    // ============================================================
    // supportsInterface (ERC-165)
    // ============================================================

    function testSupportsIOprfKeyRegistryMpc() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();
        assertTrue(v2.supportsInterface(type(IOprfKeyRegistryMpc).interfaceId));
    }

    function testSupportsIERC165() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();
        assertTrue(v2.supportsInterface(type(IERC165).interfaceId));
    }

    function testDoesNotSupportUnknownInterface() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();
        assertFalse(v2.supportsInterface(bytes4(0xdeadbeef)));
    }

    // ============================================================
    // contractCompCheck
    // ============================================================

    function testContractCompCheckSuccess() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();
        bytes32 tag = v2.domainTag();
        // should not revert
        v2.contractCompCheck(type(IOprfKeyRegistryMpc).interfaceId, tag, MAX_PEERS, THRESHOLD);
    }

    function testContractCompCheckWrongInterface() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();
        bytes32 tag = v2.domainTag();

        vm.expectRevert(OprfKeyRegistryV2.ContractComp.selector);
        v2.contractCompCheck(bytes4(0xdeadbeef), tag, MAX_PEERS, THRESHOLD);
    }

    function testContractCompCheckWrongDomainTag() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();

        vm.expectRevert(OprfKeyRegistryV2.ContractComp.selector);
        v2.contractCompCheck(type(IOprfKeyRegistryMpc).interfaceId, bytes32(uint256(1)), MAX_PEERS, THRESHOLD);
    }

    function testContractCompCheckWrongNumPeers() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();
        bytes32 tag = v2.domainTag();

        vm.expectRevert(OprfKeyRegistryV2.ContractComp.selector);
        v2.contractCompCheck(type(IOprfKeyRegistryMpc).interfaceId, tag, MAX_PEERS + 1, THRESHOLD);
    }

    function testContractCompCheckWrongThreshold() public {
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();
        bytes32 tag = v2.domainTag();

        vm.expectRevert(OprfKeyRegistryV2.ContractComp.selector);
        v2.contractCompCheck(type(IOprfKeyRegistryMpc).interfaceId, tag, MAX_PEERS, THRESHOLD + 1);
    }

    // ============================================================
    // Full upgrade flow with key generation
    // ============================================================

    function testFullUpgradeFlowWithKeyGen() public {
        // Complete a key gen on V1
        _runFullKeyGen(oprfKeyRegistry, 42);

        // Upgrade to V2 and initialize domain tag atomically
        OprfKeyRegistryV2 v2 = _upgradeAndInitV2();

        // V1 key is preserved after upgrade
        BabyJubJub.Affine memory key = v2.getOprfPublicKey(42);
        assertEq(key.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(key.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);

        // New key gen works on the upgraded V2 contract
        _runFullKeyGen(OprfKeyRegistry(address(proxy)), 43);
        BabyJubJub.Affine memory newKey = v2.getOprfPublicKey(43);
        assertEq(newKey.x, Contributions.SHOULD_OPRF_PUBLIC_KEY_X);
        assertEq(newKey.y, Contributions.SHOULD_OPRF_PUBLIC_KEY_Y);

        // contractCompCheck passes with the correct parameters
        bytes32 tag = v2.domainTag();
        v2.contractCompCheck(type(IOprfKeyRegistryMpc).interfaceId, tag, MAX_PEERS, THRESHOLD);
    }
}
