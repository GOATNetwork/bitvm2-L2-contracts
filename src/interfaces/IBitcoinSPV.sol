// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IBitcoinSPV {
    // TODO: TODO
    function validateTx(
        bytes32 txid,
        bytes calldata proof
    ) external view returns (bool);
}
