// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Constants {
    error UnsupportedChainId(uint256 chainId);

    uint256 internal constant CHAINID_TESTNET = 48816; // goat testnet chain id
    uint256 internal constant CHAINID_MAINNET = 2345; // goat mainnet chain id

    bytes8 internal constant MAGIC_BYTES_TESTNET = 0x3437353435343336; // hex(hex("GTT6"))
    bytes8 internal constant MAGIC_BYTES_MAINNET = 0x3437353435363336; // hex(hex("GTV6"))

    function magicBytes() internal view returns (bytes8) {
        if (block.chainid == CHAINID_TESTNET) return MAGIC_BYTES_TESTNET;
        if (block.chainid == CHAINID_MAINNET) return MAGIC_BYTES_MAINNET;
        revert UnsupportedChainId(block.chainid);
    }
}
