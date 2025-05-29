// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library BitvmPolicy {
    // uint64 constant minStakeAmountSats = 10000000; // 0.1 BTC
    uint64 constant minStakeAmountSats = 0; // for testing
    uint64 constant stakeRate = 200; // 2%
    uint64 constant minChallengeAmountSat = 1000000; // 0.01 BTC
    uint64 constant challengeRate = 0; // 0%
    uint64 constant rateMultiplier = 10000;

    function isValidStakeAmount(uint64 peginAmountSats, uint64 stakeAmountSats) internal pure returns (bool) {
        return stakeAmountSats >= minStakeAmountSats + peginAmountSats * stakeRate / rateMultiplier;
    }
}
