// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {
    MessageHashUtils
} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ISequencerSetPublisher} from "./interfaces/ISequencerSetPublisher.sol";
import {Constants} from "./Constants.sol";
import {BtcUtils} from "./libraries/BtcUtils.sol";

// Sequencer Set Publisher
contract SequencerSetPublisher is
    Initializable,
    OwnableUpgradeable,
    ISequencerSetPublisher
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    mapping(uint256 height => SequencerSetUpdateWitness[]) private _sequencerSetUpdateWitnesses;
    mapping(uint256 height => mapping(bytes32 pubkeyHash => bool)) private _hasWitness;

    function initialize(
        address initialOwner
    ) public initializer {
        __Ownable_init(initialOwner);
    }

    /// @notice Publish a new sequencer set or update publisher BTC key
    function updateSequencerSet(
        uint256 goatHeight,
        SequencerSetUpdateWitness calldata witness
    ) external override {
        BtcUtils.verifyBtcSignature(witness.sigHash, witness.btcPubkey, witness.btcSig);

        bytes32 pubkeyHash = keccak256(witness.btcPubkey);
        if (_hasWitness[goatHeight][pubkeyHash]) {
            revert DoubleCommit();
        }

        _hasWitness[goatHeight][pubkeyHash] = true;
        _sequencerSetUpdateWitnesses[goatHeight].push(witness);

        emit SequencerSetUpdateSubmitted(
            goatHeight,
            pubkeyHash,
            witness.btcPubkey
        );
    }

    function getSequencerSetUpdateWitnesses(
        uint256 goatHeight
    ) external view override returns (SequencerSetUpdateWitness[] memory) {
        return _sequencerSetUpdateWitnesses[goatHeight];
    }
}
