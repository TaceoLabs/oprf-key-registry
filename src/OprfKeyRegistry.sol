// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BabyJubJub} from "@taceo/babyjubjub/BabyJubJub.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OprfKeyGen} from "./OprfKeyGen.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    IOprfKeyRegistry,
    IVerifierKeyGen25,
    IVerifierKeyGen13,
    PUBLIC_INPUT_LENGTH_KEYGEN_13,
    PUBLIC_INPUT_LENGTH_KEYGEN_25
} from "./IOprfKeyRegistry.sol";

/// @dev This contract does not include a storage gap. Upgrades are expected to be
/// implemented via inheritance from this contract, which preserves the storage
/// layout. No guarantees are provided for upgrade patterns that do not inherit
/// from this contract.
contract OprfKeyRegistry is IOprfKeyRegistry, Initializable, Ownable2StepUpgradeable, UUPSUpgradeable {
    using BabyJubJub for BabyJubJub.Affine;
    using OprfKeyGen for OprfKeyGen.OprfKeyGenState;
    using OprfKeyGen for OprfKeyGen.OprfPeer;
    using OprfKeyGen for OprfKeyGen.Round1Contribution;

    // Gets set to ready state once OPRF participants are registered

    bool public isContractReady;

    // Admins to start KeyGens
    mapping(address => bool) public keygenAdmins;
    uint256 public amountKeygenAdmins;

    address public keyGenVerifier;
    uint16 public threshold;
    uint16 public numPeers;

    // The addresses of the currently participating peers.
    address[] public peerAddresses;
    // Maps the address of a peer to its party id.
    mapping(address => OprfKeyGen.OprfPeer) addressToPeer;

    // The keygen/reshare states for all OPRF key identifiers.
    mapping(uint160 => OprfKeyGen.OprfKeyGenState) internal runningKeyGens;

    // Mapping between each OPRF key identifier and the corresponding OPRF public-key.
    mapping(uint160 => OprfKeyGen.RegisteredOprfPublicKey) internal oprfKeyRegistry;

    // =============================================
    //                MODIFIERS
    // =============================================
    modifier isReady() {
        _isReady();
        _;
    }

    function _isReady() internal view {
        if (!isContractReady) revert NotReady();
    }

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        if (!keygenAdmins[msg.sender]) revert OnlyAdmin();
    }

    modifier onlyInitialized() {
        _onlyInitialized();
        _;
    }

    function _onlyInitialized() internal view {
        if (_getInitializedVersion() == 0) {
            revert ImplementationNotInitialized();
        }
    }

    modifier adminOrOwner() {
        _adminOrOwner();
        _;
    }

    function _adminOrOwner() internal view {
        bool isAdmin = keygenAdmins[msg.sender];
        bool isOwner = owner() == msg.sender;
        if (!isAdmin && !isOwner) revert OnlyAdmin();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializer function to set up the OprfKeyRegistry contract, this is not a constructor due to the use of upgradeable proxies.
    /// @param _owner The address of the contract owner, passed explicitly in initialize.
    /// @param _keygenAdmin The address of the key generation administrator, only party that is allowed to start key generation processes.
    /// @param _keyGenVerifierAddress The address of the Groth16 verifier contract for key generation (needs to be compatible with threshold numPeers values).
    /// @param _threshold The threshold number of peers required for key generation.
    /// @param _numPeers The number of peers participating in the key generation.
    function initialize(
        address _owner,
        address _keygenAdmin,
        address _keyGenVerifierAddress,
        uint16 _threshold,
        uint16 _numPeers
    ) public virtual initializer {
        __Ownable_init(_owner);
        __Ownable2Step_init();
        keygenAdmins[_keygenAdmin] = true;
        amountKeygenAdmins += 1;
        keyGenVerifier = _keyGenVerifierAddress;
        threshold = _threshold;
        numPeers = _numPeers;
        isContractReady = false;
    }

    // ==================================
    //         ADMIN FUNCTIONS
    // ==================================

    /// @inheritdoc IOprfKeyRegistry
    function revokeKeyGenAdmin(address _keygenAdmin) public virtual onlyProxy onlyInitialized onlyAdmin {
        // if the _keygenAdmin is an admin, we remove them
        if (keygenAdmins[_keygenAdmin]) {
            if (amountKeygenAdmins == 1) {
                // we don't allow the last admin to remove themselves
                revert LastAdmin();
            }
            delete keygenAdmins[_keygenAdmin];
            amountKeygenAdmins -= 1;
            emit KeyGenAdminRevoked(_keygenAdmin);
        }
    }

    /// @inheritdoc IOprfKeyRegistry
    function changeVerifierContract(address newKeyGenVerifier) public virtual onlyProxy onlyInitialized onlyOwner {
        address oldKeyGenVerifier = keyGenVerifier;
        keyGenVerifier = newKeyGenVerifier;
        emit VerifierContractChanged(oldKeyGenVerifier, newKeyGenVerifier);
    }

    /// @inheritdoc IOprfKeyRegistry
    function addKeyGenAdmin(address _keygenAdmin) public virtual onlyProxy onlyInitialized adminOrOwner {
        // if the _keygenAdmin is not yet an admin, we add them
        if (!keygenAdmins[_keygenAdmin]) {
            keygenAdmins[_keygenAdmin] = true;
            amountKeygenAdmins += 1;
            emit KeyGenAdminRegistered(_keygenAdmin);
        }
    }

    /// @inheritdoc IOprfKeyRegistry
    function registerOprfPeers(address[] calldata _peerAddresses) public virtual onlyProxy onlyInitialized onlyOwner {
        if (_peerAddresses.length != numPeers) revert UnexpectedAmountPeers(numPeers);
        // check that addresses are distinct
        for (uint256 i = 0; i < _peerAddresses.length; ++i) {
            for (uint256 j = i + 1; j < _peerAddresses.length; ++j) {
                if (_peerAddresses[i] == _peerAddresses[j]) {
                    revert PartiesNotDistinct();
                }
            }
        }
        // emit event with the new peer addresses
        for (uint256 i = 0; i < _peerAddresses.length; ++i) {
            address oldPeerAddress = peerAddresses.length > i ? peerAddresses[i] : address(0);
            if (oldPeerAddress != _peerAddresses[i]) {
                // safe cast: numPeers is uint16 and we check that _peerAddresses.length == numPeers above
                // forge-lint: disable-next-line(unsafe-typecast)
                emit OprfPeerChanged(uint16(i), oldPeerAddress, _peerAddresses[i]);
            }
        }
        // delete the old participants
        for (uint256 i = 0; i < peerAddresses.length; ++i) {
            delete addressToPeer[peerAddresses[i]];
        }
        // set the new ones
        for (uint16 i = 0; i < _peerAddresses.length; i++) {
            addressToPeer[_peerAddresses[i]] = OprfKeyGen.OprfPeer({isParticipant: true, partyId: i});
        }
        peerAddresses = _peerAddresses;
        isContractReady = true;
    }

    /// @inheritdoc IOprfKeyRegistry
    function initKeyGen(uint160 oprfKeyId) public virtual onlyProxy isReady onlyAdmin {
        if (oprfKeyId == 0) revert BadContribution();
        // Check that this oprfKeyId was not used already
        BabyJubJub.Affine storage publicKey = oprfKeyRegistry[oprfKeyId].key;
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];

        // check if deleted
        if (st.currentRound == OprfKeyGen.Round.DELETED) revert DeletedId(oprfKeyId);

        // check if resubmit
        if (!publicKey.isEmpty() || st.currentRound != OprfKeyGen.Round.NOT_STARTED) {
            revert AlreadySubmitted();
        }

        st.initKeyGen(numPeers);
        // Emit Round1 event for everyone
        emit SecretGenRound1(oprfKeyId, threshold);
    }

    /// @inheritdoc IOprfKeyRegistry
    function initReshare(uint160 oprfKeyId) public virtual onlyProxy isReady onlyAdmin {
        // Get the key-gen state for this key and reset everything
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        // check if deleted
        if (st.currentRound == OprfKeyGen.Round.DELETED) revert DeletedId(oprfKeyId);
        // check if resubmit
        if (st.currentRound != OprfKeyGen.Round.NOT_STARTED) {
            revert AlreadySubmitted();
        }

        // Check that this oprfKeyId already exists
        OprfKeyGen.RegisteredOprfPublicKey storage oprfPublicKey = oprfKeyRegistry[oprfKeyId];
        if (oprfPublicKey.key.isEmpty()) revert UnknownId(oprfKeyId);

        // we need to leave the share commitments to check the peers are using the correct input
        st.initReshare(numPeers, oprfPublicKey.epoch + 1);
        // Emit Round1 event for everyone
        emit ReshareRound1(oprfKeyId, threshold, st.generatedEpoch);
    }

    /// @inheritdoc IOprfKeyRegistry
    function deleteOprfPublicKey(uint160 oprfKeyId) public virtual onlyProxy isReady onlyAdmin {
        // check whether this key was registered
        OprfKeyGen.RegisteredOprfPublicKey storage oprfPublicKey = oprfKeyRegistry[oprfKeyId];
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        if (st.currentRound != OprfKeyGen.Round.NOT_STARTED) {
            revert WrongRound(st.currentRound);
        }
        if (!oprfPublicKey.key.isEmpty()) {
            // delete the created key
            delete oprfPublicKey.key;
            delete oprfPublicKey.epoch;

            // delete the runningKeyGen data as well
            st.deleteSt(numPeers, peerAddresses);
            emit KeyDeletion(oprfKeyId);
        } else {
            revert UnknownId(oprfKeyId);
        }
    }

    /// @inheritdoc IOprfKeyRegistry
    function abortKeyGen(uint160 oprfKeyId) public virtual onlyProxy isReady onlyAdmin {
        // Get the key-gen state for this key and check that it actually exists
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        if (st.currentRound == OprfKeyGen.Round.NOT_STARTED) {
            revert UnknownId(oprfKeyId);
        }
        if (st.currentRound == OprfKeyGen.Round.DELETED) {
            revert DeletedId(oprfKeyId);
        }
        st.reset(numPeers, peerAddresses);
        emit KeyGenAbort(oprfKeyId);
    }

    // ==================================
    //        OPRF Peer FUNCTIONS
    // ==================================

    /// @inheritdoc IOprfKeyRegistry
    function addRound1KeyGenContribution(uint160 oprfKeyId, OprfKeyGen.Round1Contribution calldata data)
        public
        virtual
        onlyProxy
        isReady
    {
        // return the partyId if sender is really a participant
        uint16 partyId = _internParticipantCheck();
        // for key-gen everyone is a producer, therefore we check that all values are set and valid points
        _curveChecks(data.commShare);
        if (data.commCoeffs == 0) revert BadContribution();
        OprfKeyGen.OprfKeyGenState storage st = _addRound1Contribution(oprfKeyId, partyId, data);
        // check that this is a key-gen
        if (st.generatedEpoch != 0) {
            revert BadContribution();
        }
        st.nodeRoles[msg.sender] = OprfKeyGen.KeyGenRole.PRODUCER;
        st.numProducers += 1;
        // Add BabyJubJub Elements together and keep running total
        _addToAggregate(st.keyAggregate, data.commShare);
        // everyone is a producer therefore we wait for numPeers amount producers
        _tryEmitRound2Event(oprfKeyId, numPeers, st);
        // Emit the transaction confirmation
        emit KeyGenConfirmation(oprfKeyId, partyId, 1, st.generatedEpoch);
    }

    /// @inheritdoc IOprfKeyRegistry
    function addRound1ReshareContribution(uint160 oprfKeyId, OprfKeyGen.Round1Contribution calldata data)
        public
        virtual
        onlyProxy
        isReady
    {
        // as we need contributions from everyone we check the
        // return the partyId if sender is really a participant
        uint16 partyId = _internParticipantCheck();
        // in reshare we can have producers and consumers, therefore we don't need to enforce that commitments are non-zero
        OprfKeyGen.OprfKeyGenState storage st = _addRound1Contribution(oprfKeyId, partyId, data);
        // check that this is in fact a reshare
        if (st.generatedEpoch == 0) {
            revert BadContribution();
        }
        // check if someone wants to be a consumer
        bool isEmptyCommShare = data.commShare.isEmpty();
        bool isEmptyCommCoeffs = data.commCoeffs == 0;
        if ((isEmptyCommShare && isEmptyCommCoeffs) || st.numProducers >= threshold) {
            // both are empty or we already have enough producers
            st.nodeRoles[msg.sender] = OprfKeyGen.KeyGenRole.CONSUMER;
            // as a consolation prize we at least refund some storage costs
            delete st.round1[partyId].commShare;
            delete st.round1[partyId].commCoeffs;
        } else if (isEmptyCommShare != isEmptyCommCoeffs) {
            // sanity check that someone doesn't try to only commit to one value
            revert BadContribution();
        } else {
            // both commitments are set and we still need more producers
            _curveChecks(data.commShare);
            // in contrast to key-gen we don't compute the running total, but we can check whether the commitments are correct from the previous reshare/key-gen.
            BabyJubJub.Affine memory shouldCommitment = st.prevShareCommitments[partyId];
            if (!BabyJubJub.isEqual(shouldCommitment, data.commShare)) {
                revert BadContribution();
            }
            st.nodeRoles[msg.sender] = OprfKeyGen.KeyGenRole.PRODUCER;
            st.numProducers += 1;
            // check if we are the last producer, then we can compute the lagrange coefficients
            if (st.numProducers == threshold) {
                // first get all producer ids
                // iterating over the peers in that order always returns the ids in ascending order. This is important because the contributions in round 2 will also be in this order.
                uint256[] memory ids = new uint256[](threshold);
                uint256 counter = 0;
                for (uint256 i = 0; i < numPeers; ++i) {
                    address peerAddress = peerAddresses[i];
                    if (OprfKeyGen.KeyGenRole.PRODUCER == st.nodeRoles[peerAddress]) {
                        ids[counter++] = addressToPeer[peerAddress].partyId;
                    }
                }
                // then compute the coefficients
                st.lagrangeCoeffs = BabyJubJub.computeLagrangeCoefficiants(ids, threshold, numPeers);
            }
        }
        // we need a contribution from everyone but only threshold many producers. If we don't manage to find enough producers, we will emit an event so that the admin can intervene.
        _tryEmitRound2Event(oprfKeyId, threshold, st);
        // Emit the transaction confirmation
        emit KeyGenConfirmation(oprfKeyId, partyId, 1, st.generatedEpoch);
    }

    /// @inheritdoc IOprfKeyRegistry
    function addRound2Contribution(uint160 oprfKeyId, OprfKeyGen.Round2Contribution calldata data)
        public
        virtual
        onlyProxy
        isReady
    {
        // check that the contribution is complete
        if (data.ciphers.length != numPeers) revert BadContribution();
        // check that we started the key-gen for this OPRF public-key.
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        // check that we are actually in round2
        if (st.currentRound != OprfKeyGen.Round.TWO) revert WrongRound(st.currentRound);

        // return the partyId if sender is really a participant
        uint16 partyId = _internParticipantCheck();
        // check that this peer did not submit anything for this round
        if (st.round2Done[partyId]) revert AlreadySubmitted();
        // check that this peer is a producer for this round
        if (OprfKeyGen.KeyGenRole.PRODUCER != st.nodeRoles[msg.sender]) revert BadContribution();

        // everything looks good - push the ciphertexts
        // additionally accumulate all commitments for the parties to have the correct commitment during the reshare process.
        //
        // this differs if this is the initial key-gen or one of the reshares
        if (st.generatedEpoch == 0) {
            // for the key-gen we simply accumulate all commitments as the resulting shamir-share should have contributions from all parties -> just add all together
            for (uint256 i = 0; i < numPeers; ++i) {
                _curveChecks(data.ciphers[i].commitment);
                _addToAggregate(st.shareCommitments[i], data.ciphers[i].commitment);
                st.round2[i][partyId] = data.ciphers[i];
            }
        } else {
            // for the reshare we need to use the lagrange coefficients as here the resulting shamir-share is shared with shamir sharing
            uint256 lagrange = st.lagrangeCoeffs[partyId];
            require(lagrange > 0, "SAFETY CHECK: this should never happen. This means there is a bug");
            for (uint256 i = 0; i < numPeers; ++i) {
                _curveChecks(data.ciphers[i].commitment);
                BabyJubJub.Affine memory lagrangeResult = BabyJubJub.scalarMul(lagrange, data.ciphers[i].commitment);
                _addToAggregate(st.shareCommitments[i], lagrangeResult);
                st.round2[i][partyId] = data.ciphers[i];
            }
        }
        // set the contribution to done
        st.round2Done[partyId] = true;

        // last step verify the proof and potentially revert if proof fails

        // build the public input:
        // 1) PublicKey from sender (Affine Point Babyjubjub)
        // 2) Commitment to share (Affine Point Babyjubjub)
        // 3) Commitment to coeffs (Basefield Babyjubjub)
        // 4) Ciphertexts for peers (in this case 3 Basefield BabyJubJub)
        // 5) Commitments to plaintexts (in this case 3 Affine Points BabyJubJub)
        // 6) Degree (Basefield BabyJubJub)
        // 7) Public Keys from peers (in this case 3 Affine Points BabyJubJub)
        // 8) Nonces (in this case 3 Basefield BabyJubJub)

        // TODO this is currently hardcoded for 13 and 25 need to make this more generic later
        if (numPeers == 3 && threshold == 2) {
            IVerifierKeyGen13 keyGenVerifier13 = IVerifierKeyGen13(keyGenVerifier);

            uint256[PUBLIC_INPUT_LENGTH_KEYGEN_13] memory publicInputs;

            BabyJubJub.Affine[] memory pubKeyList = _loadPeerPublicKeys(st);
            publicInputs[0] = pubKeyList[partyId].x;
            publicInputs[1] = pubKeyList[partyId].y;
            publicInputs[2] = st.round1[partyId].commShare.x;
            publicInputs[3] = st.round1[partyId].commShare.y;
            publicInputs[4] = st.round1[partyId].commCoeffs;
            publicInputs[5 + (numPeers * 3)] = threshold - 1;
            // peer keys
            for (uint256 i = 0; i < numPeers; ++i) {
                publicInputs[5 + i] = data.ciphers[i].cipher;
                publicInputs[5 + numPeers + (i * 2) + 0] = data.ciphers[i].commitment.x;
                publicInputs[5 + numPeers + (i * 2) + 1] = data.ciphers[i].commitment.y;
                publicInputs[5 + (numPeers * 3) + 1 + (i * 2) + 0] = pubKeyList[i].x;
                publicInputs[5 + (numPeers * 3) + 1 + (i * 2) + 1] = pubKeyList[i].y;
                publicInputs[5 + (numPeers * 5) + 1 + i] = data.ciphers[i].nonce;
            }
            // As last step we call the foreign contract and revert the whole transaction in case anything is wrong.
            keyGenVerifier13.verifyCompressedProof(data.compressedProof, publicInputs);
        } else if (numPeers == 5 && threshold == 3) {
            IVerifierKeyGen25 keyGenVerifier25 = IVerifierKeyGen25(keyGenVerifier);

            uint256[PUBLIC_INPUT_LENGTH_KEYGEN_25] memory publicInputs;

            BabyJubJub.Affine[] memory pubKeyList = _loadPeerPublicKeys(st);
            publicInputs[0] = pubKeyList[partyId].x;
            publicInputs[1] = pubKeyList[partyId].y;
            publicInputs[2] = st.round1[partyId].commShare.x;
            publicInputs[3] = st.round1[partyId].commShare.y;
            publicInputs[4] = st.round1[partyId].commCoeffs;
            publicInputs[5 + (numPeers * 3)] = threshold - 1;
            // peer keys
            for (uint256 i = 0; i < numPeers; ++i) {
                publicInputs[5 + i] = data.ciphers[i].cipher;
                publicInputs[5 + numPeers + (i * 2) + 0] = data.ciphers[i].commitment.x;
                publicInputs[5 + numPeers + (i * 2) + 1] = data.ciphers[i].commitment.y;
                publicInputs[5 + (numPeers * 3) + 1 + (i * 2) + 0] = pubKeyList[i].x;
                publicInputs[5 + (numPeers * 3) + 1 + (i * 2) + 1] = pubKeyList[i].y;
                publicInputs[5 + (numPeers * 5) + 1 + i] = data.ciphers[i].nonce;
            }
            // As last step we call the foreign contract and revert the whole transaction in case anything is wrong.
            keyGenVerifier25.verifyCompressedProof(data.compressedProof, publicInputs);
        } else {
            revert UnsupportedNumPeersThreshold();
        }
        // depending on key-gen or reshare a different amount of producers
        uint256 necessaryContributions = st.generatedEpoch == 0 ? numPeers : threshold;
        _tryEmitRound3Event(oprfKeyId, necessaryContributions, st);

        // Emit the transaction confirmation
        emit KeyGenConfirmation(oprfKeyId, partyId, 2, st.generatedEpoch);
    }

    /// @inheritdoc IOprfKeyRegistry
    function addRound3Contribution(uint160 oprfKeyId) public virtual onlyProxy isReady {
        // check that we started the key-gen for this OPRF public-key.
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        // check that we are actually in round3
        if (st.currentRound != OprfKeyGen.Round.THREE) revert WrongRound(st.currentRound);
        // return the partyId if sender is really a participant
        uint16 partyId = _internParticipantCheck();
        // check that this peer did not submit anything for this round
        if (st.round3Done[partyId]) revert AlreadySubmitted();
        st.round3Done[partyId] = true;

        // load generated epoch before delete to emit correct value
        uint32 generatedEpoch = st.generatedEpoch;

        if (allRound3Submitted(st)) {
            // We are done! Register the OPRF public-key and emit event!
            if (st.generatedEpoch == 0) {
                oprfKeyRegistry[oprfKeyId] = OprfKeyGen.RegisteredOprfPublicKey({key: st.keyAggregate, epoch: 0});
            } else {
                // we simply increase the current epoch
                oprfKeyRegistry[oprfKeyId].epoch = st.generatedEpoch;
            }
            // Save the current share commitments for the next reshare
            st.prevShareCommitments = st.shareCommitments;

            emit SecretGenFinalize(oprfKeyId, st.generatedEpoch);
            // cleanup all old data - we need to keep shareCommitments though otherwise we can't do reshares
            st.reset(numPeers, peerAddresses);
        }
        // Emit the transaction confirmation
        emit KeyGenConfirmation(oprfKeyId, partyId, 3, generatedEpoch);
    }

    // ==================================
    //           HELPER FUNCTIONS
    // ==================================

    /// @inheritdoc IOprfKeyRegistry
    function getPartyIdForParticipant(address participant) public view virtual isReady onlyProxy returns (uint256) {
        OprfKeyGen.OprfPeer memory peer = addressToPeer[participant];
        if (!peer.isParticipant) revert NotAParticipant();
        return peer.partyId;
    }

    function _internParticipantCheck() internal view virtual returns (uint16) {
        OprfKeyGen.OprfPeer memory peer = addressToPeer[msg.sender];
        if (!peer.isParticipant) revert NotAParticipant();
        return peer.partyId;
    }

    /// @inheritdoc IOprfKeyRegistry
    function loadPeerPublicKeysForProducers(uint160 oprfKeyId)
        public
        view
        virtual
        isReady
        onlyProxy
        returns (BabyJubJub.Affine[] memory)
    {
        // check if a participant
        OprfKeyGen.OprfPeer memory peer = addressToPeer[msg.sender];
        if (!peer.isParticipant) revert NotAParticipant();

        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        // check if we are in correct round
        if (st.currentRound != OprfKeyGen.Round.TWO) revert WrongRound(st.currentRound);
        // check if we are a producer
        if (OprfKeyGen.KeyGenRole.PRODUCER != st.nodeRoles[msg.sender]) {
            // we are not a producer -> return empty array
            return new BabyJubJub.Affine[](0);
        }
        return _loadPeerPublicKeys(st);
    }

    /// @inheritdoc IOprfKeyRegistry
    function loadPeerPublicKeysForConsumers(uint160 oprfKeyId)
        public
        view
        virtual
        isReady
        onlyProxy
        returns (BabyJubJub.Affine[] memory)
    {
        // check if a participant
        OprfKeyGen.OprfPeer memory peer = addressToPeer[msg.sender];
        if (!peer.isParticipant) revert NotAParticipant();

        // check if there exists this key-gen
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        // check if we are in correct round
        if (st.currentRound != OprfKeyGen.Round.THREE) revert WrongRound(st.currentRound);
        // load the producer's keys for decryption
        return _loadProducerPeerPublicKeys(st);
    }

    /// @inheritdoc IOprfKeyRegistry
    function checkIsParticipantAndReturnRound2Ciphers(uint160 oprfKeyId)
        public
        view
        virtual
        onlyProxy
        isReady
        returns (OprfKeyGen.SecretGenCiphertext[] memory)
    {
        // check if a participant
        OprfKeyGen.OprfPeer memory peer = addressToPeer[msg.sender];
        if (!peer.isParticipant) revert NotAParticipant();
        // check if there exists this a key-gen
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        // check that round2 ciphers are finished
        if (st.currentRound != OprfKeyGen.Round.THREE) revert WrongRound(st.currentRound);
        if (st.generatedEpoch == 0) {
            // this is a key-gen so just send all ciphers
            return st.round2[peer.partyId];
        } else {
            // this is a reshare -> find the contributions by the producers
            OprfKeyGen.SecretGenCiphertext[] memory ciphers = new OprfKeyGen.SecretGenCiphertext[](threshold);
            uint256 counter = 0;
            for (uint256 i = 0; i < numPeers; ++i) {
                if (OprfKeyGen.KeyGenRole.PRODUCER == st.nodeRoles[peerAddresses[i]]) {
                    ciphers[counter++] = st.round2[peer.partyId][i];
                }
            }
            return ciphers;
        }
    }

    /// @inheritdoc IOprfKeyRegistry
    function getOprfPublicKey(uint160 oprfKeyId)
        public
        view
        virtual
        onlyProxy
        isReady
        returns (BabyJubJub.Affine memory)
    {
        // check if deleted
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        if (st.currentRound == OprfKeyGen.Round.DELETED) revert DeletedId(oprfKeyId);
        BabyJubJub.Affine storage publicKey = oprfKeyRegistry[oprfKeyId].key;
        if (publicKey.isEmpty()) revert UnknownId(oprfKeyId);
        return publicKey;
    }

    /// @inheritdoc IOprfKeyRegistry
    function getOprfPublicKeyAndEpoch(uint160 oprfKeyId)
        public
        view
        virtual
        onlyProxy
        isReady
        returns (OprfKeyGen.RegisteredOprfPublicKey memory)
    {
        // check if deleted
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        if (st.currentRound == OprfKeyGen.Round.DELETED) revert DeletedId(oprfKeyId);
        OprfKeyGen.RegisteredOprfPublicKey storage oprfPublicKey = oprfKeyRegistry[oprfKeyId];
        if (oprfPublicKey.key.isEmpty()) revert UnknownId(oprfKeyId);
        return oprfPublicKey;
    }

    function allRound1Submitted(OprfKeyGen.OprfKeyGenState storage st) internal view virtual returns (bool) {
        for (uint256 i = 0; i < numPeers; ++i) {
            if (OprfKeyGen.KeyGenRole.NOT_READY == st.nodeRoles[peerAddresses[i]]) {
                return false;
            }
        }
        return true;
    }

    function allProducersRound2Submitted(uint256 necessaryProducers, OprfKeyGen.OprfKeyGenState storage st)
        internal
        view
        virtual
        returns (bool)
    {
        uint256 submissions = 0;
        for (uint256 i = 0; i < numPeers; ++i) {
            if (st.round2Done[i]) submissions += 1;
        }
        return submissions == necessaryProducers;
    }

    function allRound3Submitted(OprfKeyGen.OprfKeyGenState storage st) internal view virtual returns (bool) {
        for (uint256 i = 0; i < numPeers; ++i) {
            if (!st.round3Done[i]) return false;
        }
        return true;
    }

    function _addRound1Contribution(uint160 oprfKeyId, uint256 partyId, OprfKeyGen.Round1Contribution calldata data)
        internal
        returns (OprfKeyGen.OprfKeyGenState storage)
    {
        _curveChecks(data.ephPubKey);
        // check that we started the key-gen for this OPRF public-key
        OprfKeyGen.OprfKeyGenState storage st = runningKeyGens[oprfKeyId];
        // check that we are in correct round
        if (st.currentRound != OprfKeyGen.Round.ONE) revert WrongRound(st.currentRound);
        // check that the provided ephPubKey is distinct to prevent replay attacks
        _ephKeyUniqueCheck(st, data.ephPubKey);
        // check that we don't have double submission
        if (!st.round1[partyId].commShare.isEmpty()) revert AlreadySubmitted();
        st.round1[partyId] = data;
        return st;
    }

    function _loadPeerPublicKeys(OprfKeyGen.OprfKeyGenState storage st)
        internal
        view
        returns (BabyJubJub.Affine[] memory)
    {
        BabyJubJub.Affine[] memory pubKeyList = new BabyJubJub.Affine[](numPeers);
        for (uint256 i = 0; i < numPeers; ++i) {
            pubKeyList[i] = st.round1[i].ephPubKey;
        }
        return pubKeyList;
    }

    function _loadProducerPeerPublicKeys(OprfKeyGen.OprfKeyGenState storage st)
        internal
        view
        returns (BabyJubJub.Affine[] memory)
    {
        BabyJubJub.Affine[] memory pubKeyList = new BabyJubJub.Affine[](st.numProducers);
        uint256 counter = 0;
        for (uint256 i = 0; i < numPeers; ++i) {
            if (OprfKeyGen.KeyGenRole.PRODUCER == st.nodeRoles[peerAddresses[i]]) {
                pubKeyList[counter++] = st.round1[i].ephPubKey;
            }
        }
        return pubKeyList;
    }

    function _tryEmitRound2Event(
        uint160 oprfKeyId,
        uint256 necessaryContributions,
        OprfKeyGen.OprfKeyGenState storage st
    ) internal virtual {
        if (st.currentRound != OprfKeyGen.Round.ONE) return;
        if (!allRound1Submitted(st)) return;
        if (st.numProducers < necessaryContributions) {
            // everyone contributed but we are don't have enough producers. This is an alert and we need to abort!
            emit NotEnoughProducers(oprfKeyId);
            st.currentRound = OprfKeyGen.Round.STUCK;
        } else {
            st.currentRound = OprfKeyGen.Round.TWO;
            st.shareCommitments = new BabyJubJub.Affine[](numPeers);
            emit SecretGenRound2(oprfKeyId, st.generatedEpoch);
        }
    }

    function _tryEmitRound3Event(
        uint160 oprfKeyId,
        uint256 necessaryContributions,
        OprfKeyGen.OprfKeyGenState storage st
    ) internal virtual {
        if (st.currentRound != OprfKeyGen.Round.TWO) return;
        if (!allProducersRound2Submitted(necessaryContributions, st)) return;

        st.currentRound = OprfKeyGen.Round.THREE;
        if (st.generatedEpoch == 0) {
            emit SecretGenRound3(oprfKeyId);
        } else {
            emit ReshareRound3(oprfKeyId, st.lagrangeCoeffs, st.generatedEpoch);
        }
    }

    // Expects that callsite enforces that point is on the curve and in the correct sub-group (i.e. call _curveCheck).
    function _addToAggregate(BabyJubJub.Affine storage keyAggregate, BabyJubJub.Affine memory commShare)
        internal
        virtual
    {
        if (keyAggregate.isEmpty()) {
            // We checked above that the point is on curve, so we can just set it
            keyAggregate.x = commShare.x;
            keyAggregate.y = commShare.y;
            return;
        }

        // we checked above that the new point is on curve
        // the initial aggregate is on curve as well, checked inside the if above
        // induction: sum of two on-curve points is on-curve, so the result is on-curve as well
        BabyJubJub.Affine memory result = BabyJubJub.add(keyAggregate, commShare);
        keyAggregate.x = result.x;
        keyAggregate.y = result.y;
    }

    /// Performs sanity checks on BabyJubJub elements. If either the point
    ///     * is the identity
    ///     * is not on the curve
    ///     * is not in the large sub-group
    ///
    /// this method will revert the call.
    function _curveChecks(BabyJubJub.Affine memory element) internal view virtual {
        if (
            BabyJubJub.isIdentity(element) || !BabyJubJub.isOnCurve(element)
                || !BabyJubJub.isInCorrectSubgroupAssumingOnCurve(element)
        ) {
            revert BadContribution();
        }
    }

    // Performs a uniqueness check for the provided ephemeral public key,
    // which is a BabyJubJub point in affine coordinates.
    //
    // This method iterates over all ephemeral public keys submitted in round 1
    // (including uninitialized entries) and checks that the provided public key
    // (`needle`) is unique.
    function _ephKeyUniqueCheck(OprfKeyGen.OprfKeyGenState storage st, BabyJubJub.Affine calldata needle)
        internal
        view
        virtual
    {
        // Ensure that the provided ephemeral public key is distinct to prevent replay attacks.
        for (uint256 i = 0; i < numPeers; ++i) {
            if (BabyJubJub.isEqual(st.round1[i].ephPubKey, needle)) {
                revert BadContribution();
            }
        }
    }
    ////////////////////////////////////////////////////////////
    //                    Upgrade Authorization               //
    ////////////////////////////////////////////////////////////

    /**
     *
     *
     * @dev Authorize upgrade to a new implementation
     *
     *
     * @param newImplementation Address of the new implementation contract
     *
     *
     * @notice Only the contract owner can authorize upgrades
     *
     *
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    /* Storage gap:
     * We do not include a storage gap due to the way we expect upgrades to work in practice.
     * All upgrades are expected to be implemented as child contracts inheriting from this
     * contract, which preserves the original storage layout and appends any new state
     * variables in the derived contract.
     *
     * No guarantees are made for contracts that rely on this contract’s storage layout
     * without inheriting from it.
     */
}
