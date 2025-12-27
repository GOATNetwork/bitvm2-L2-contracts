// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISequencerSetPublisher {
    error DoubleCommit();
    error InvalidBtcSignature();
    error InvalidBtcPubkey();
    error InvalidPubkeyLength();
    error InvalidPublicKeyX();
    error ModexpFailed();

    struct SequencerSetUpdateWitness {
        bytes32 sigHash;
        bytes btcPubkey;
        bytes btcSig;
    }

    function updateSequencerSet(
        uint256 goatHeight,
        SequencerSetUpdateWitness calldata witness
    ) external;
}
