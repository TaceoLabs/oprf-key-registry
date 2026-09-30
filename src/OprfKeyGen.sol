// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BabyJubJub} from "@taceo/babyjubjub/BabyJubJub.sol";

/// @title Types Library
/// @notice Defines common structs, enums, and constants for the project
library OprfKeyGen {
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
        // currently not used other than preventing that this key-gen is used for anything else
        STUCK,
        DELETED
    }

    struct OprfPeer {
        bool isParticipant;
        uint16 partyId;
    }

    struct RegisteredOprfPublicKey {
        BabyJubJub.Affine key;
        uint32 epoch;
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
        // ---- legacy fields (written by v1/v2, no longer used). Kept for storage-layout compatibility. ----
        mapping(address => KeyGenRole) nodeRoles;
        uint256[] lagrangeCoeffs;
        Round1Contribution[] round1;
        SecretGenCiphertext[][] round2;
        BabyJubJub.Affine[] shareCommitments;
        // ---- live fields ----
        // share commitments of the last finalized key-gen/reshare, checked in the next reshare's round 1
        BabyJubJub.Affine[] prevShareCommitments;
        // running total of the round 1 commitments during a key-gen (becomes the OPRF public-key)
        BabyJubJub.Affine keyAggregate;
        // legacy, replaced by popcount(producerMask)
        uint32 numProducers;
        uint32 generatedEpoch;
        // legacy, replaced by round2Mask/round3Mask
        bool[] round2Done;
        bool[] round3Done;
        Round currentRound;
        // ---- appended in v3: round data keyed by party id, submissions tracked by bitmasks. ----
        // Nothing below is ever cleared; an entry is valid iff the corresponding mask bit is set for the current run.
        // Overwriting stale slots is much cheaper than zeroing and re-allocating them (EIP-3529).
        uint64 round1Mask;
        uint64 producerMask;
        uint64 round2Mask;
        uint64 round3Mask;
        mapping(uint256 => Round1Contribution) round1Data;
        // receiver party id => sender party id => ciphertext
        mapping(uint256 => mapping(uint256 => SecretGenCiphertext)) round2Data;
        // per receiver: aggregate of the round 2 commitments of the current run
        mapping(uint256 => BabyJubJub.Affine) shareCommitmentAcc;
    }

    /// @dev Bitmasks are uint64, so at most 64 peers are supported.
    uint256 internal constant MAX_PEERS = 64;

    /// @notice Initializes the internal state for a new OPRF key-generation process.
    ///
    /// @dev Only resets the bookkeeping; round data is invalidated by clearing the masks.
    ///
    /// @param st The key-generation state to initialize.
    function initKeyGen(OprfKeyGenState storage st) internal {
        _init(st, 0);
    }

    /// @notice Initializes the internal state for an OPRF reshare process.
    ///
    /// @dev Preserves the previous share commitments for input verification.
    ///
    /// @param st The key-generation state to initialize.
    /// @param generatedEpoch The new epoch to assign to the reshared key.
    function initReshare(OprfKeyGenState storage st, uint32 generatedEpoch) internal {
        _init(st, generatedEpoch);
    }

    /// @notice Resets the key-generation state to allow a fresh initialization.
    ///
    /// @dev Round data stays in storage but is invalidated at the next init. Sets the current round to `NOT_STARTED`.
    ///
    /// @param st The key-generation state to reset.
    function reset(OprfKeyGenState storage st) internal {
        st.currentRound = Round.NOT_STARTED;
    }

    /// @notice Deletes the key-generation state permanently.
    ///
    /// @dev Clears the persistent share commitments and marks the key ID as deleted to prevent
    /// reuse. Sets the current round to `DELETED`.
    ///
    /// @param st The key-generation state to delete.
    function deleteSt(OprfKeyGenState storage st) internal {
        delete st.prevShareCommitments;
        delete st.keyAggregate;
        st.currentRound = Round.DELETED;
    }

    function _init(OprfKeyGenState storage st, uint32 generatedEpoch) private {
        st.currentRound = Round.ONE;
        st.generatedEpoch = generatedEpoch;
        st.round1Mask = 0;
        st.producerMask = 0;
        st.round2Mask = 0;
        st.round3Mask = 0;
    }

    /// @notice Returns the bit of the given party in the masks.
    function bit(uint256 partyId) internal pure returns (uint64) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint64(1 << partyId);
    }

    /// @notice Number of set bits.
    function popcount(uint64 mask) internal pure returns (uint256 count) {
        uint256 m = mask;
        while (m != 0) {
            m &= m - 1;
            ++count;
        }
    }

    /// @notice Number of producers of the current run.
    function numProducersOf(OprfKeyGenState storage st) internal view returns (uint256) {
        return popcount(st.producerMask);
    }
}
