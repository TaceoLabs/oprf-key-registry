// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BabyJubJub} from "./BabyJubJub.sol";

/// @title Types Library
/// @notice Defines common structs, enums, and constants for the project
library Types {
    // The roles of the nodes during key-gen. NOT_READY is the default value
    enum KeyGenRole {
        NOT_READY,
        PRODUCER,
        CONSUMER
    }

    enum Round {
        NOT_STARTED,
        ONE,
        TWO,
        THREE,
        STUCK,
        DELETED
    }

    struct OprfPeer {
        bool isParticipant;
        uint16 partyId;
    }

    struct RegisteredOprfPublicKey {
        BabyJubJub.Affine key;
        uint128 epoch;
    }

    struct Round1Contribution {
        // the commitment to the secret
        BabyJubJub.Affine commShare;
        // hash of the polynomial created by participant
        uint256 commCoeffs;
        // ephemeral public key for this round
        BabyJubJub.Affine ephPubKey;
    }

    struct Round2Contribution {
        uint256[4] compressedProof;
        // Hash of the polynomial created by participant
        SecretGenCiphertext[] ciphers;
    }

    struct SecretGenCiphertext {
        uint256 nonce;
        uint256 cipher;
        BabyJubJub.Affine commitment;
    }

    struct OprfKeyGenState {
        mapping(address => KeyGenRole) nodeRoles;
        uint256[] lagrangeCoeffs;
        Round1Contribution[] round1;
        SecretGenCiphertext[][] round2;
        BabyJubJub.Affine[] shareCommitments;
        BabyJubJub.Affine[] prevShareCommitments;
        BabyJubJub.Affine keyAggregate;
        uint128 numProducers;
        uint128 generatedEpoch;
        bool[] round2Done;
        bool[] round3Done;
        Round currentRound;
    }

    struct Groth16Proof {
        uint256[2] pA;
        uint256[2][2] pB;
        uint256[2] pC;
    }

    // Event that will be emitted during transaction of key-gens. This should signal the MPC-nodes that their transaction was successfully registered.
    event KeyGenConfirmation(uint160 indexed oprfKeyId, uint16 partyId, uint8 round, uint128 epoch);
    // events for key-gen
    event SecretGenRound1(uint160 indexed oprfKeyId, uint256 threshold);
    event SecretGenRound2(uint160 indexed oprfKeyId, uint128 indexed epoch);
    event SecretGenRound3(uint160 indexed oprfKeyId);
    event SecretGenFinalize(uint160 indexed oprfKeyId, uint128 indexed epoch);
    // events for reshare
    event ReshareRound1(uint160 indexed oprfKeyId, uint256 threshold, uint128 indexed epoch);
    event ReshareRound3(uint160 indexed oprfKeyId, uint256[] lagrange, uint128 indexed epoch);
    // event to delete created key
    event KeyDeletion(uint160 indexed oprfKeyId);
    // abort currently running key-gen
    event KeyGenAbort(uint160 indexed oprfKeyId);
    // admin events
    event KeyGenAdminRevoked(address indexed admin);
    event KeyGenAdminRegistered(address indexed admin);
    event NotEnoughProducers(uint160 indexed oprfKeyId);

    function initKeyGen(Types.OprfKeyGenState storage st, uint256 numPeers, address[] memory peerAddresses) internal {
        st.currentRound = Round.ONE;
        st.generatedEpoch = 0;
        st.round1 = new Types.Round1Contribution[](numPeers);
        st.round2 = new Types.SecretGenCiphertext[][](numPeers);
        for (uint256 i = 0; i < numPeers; i++) {
            delete st.nodeRoles[peerAddresses[i]];
            st.round2[i] = new Types.SecretGenCiphertext[](numPeers);
        }
        st.shareCommitments = new BabyJubJub.Affine[](numPeers);
        st.prevShareCommitments = new BabyJubJub.Affine[](numPeers);
        st.round2Done = new bool[](numPeers);
        st.round3Done = new bool[](numPeers);
    }

    function initReshare(
        Types.OprfKeyGenState storage st,
        uint256 numPeers,
        address[] memory peerAddresses,
        uint128 generatedEpoch
    ) internal {
        delete st.lagrangeCoeffs;

        st.currentRound = Round.ONE;
        st.generatedEpoch = generatedEpoch;
        st.round1 = new Types.Round1Contribution[](numPeers);
        st.round2 = new Types.SecretGenCiphertext[][](numPeers);
        for (uint256 i = 0; i < numPeers; i++) {
            delete st.nodeRoles[peerAddresses[i]];
            st.round2[i] = new Types.SecretGenCiphertext[](numPeers);
        }
        st.shareCommitments = new BabyJubJub.Affine[](numPeers);
        st.round2Done = new bool[](numPeers);
        st.round3Done = new bool[](numPeers);
    }

    function reset(Types.OprfKeyGenState storage st, uint256 numPeers, address[] memory peerAddresses) internal {
        _reset(st, numPeers, peerAddresses);
        st.currentRound = Round.NOT_STARTED;
    }

    function deleteSt(Types.OprfKeyGenState storage st, uint256 numPeers, address[] memory peerAddresses) internal {
        _reset(st, numPeers, peerAddresses);
        delete st.lagrangeCoeffs;
        delete st.prevShareCommitments;
        st.currentRound = Round.DELETED;
    }

    function _reset(Types.OprfKeyGenState storage st, uint256 numPeers, address[] memory peerAddresses) private {
        delete st.keyAggregate;
        delete st.round2Done;
        delete st.round3Done;
        delete st.round1;
        delete st.round2;
        delete st.numProducers;
        delete st.generatedEpoch;
        for (uint256 i = 0; i < numPeers; i++) {
            delete st.nodeRoles[peerAddresses[i]];
        }
        delete st.shareCommitments;
    }
}
