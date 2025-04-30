// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library BitvmPolicy {
    // uint64 constant minStakeAmountSats = 10000000; // 0.1 BTC
    uint64 constant minStakeAmountSats = 0; // for testing

    function isValidStakeAmount(
        uint64 amountSats
    ) internal pure returns (bool) {
        return amountSats >= minStakeAmountSats;
    }
}
