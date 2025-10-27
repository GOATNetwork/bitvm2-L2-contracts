// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { GatewayUpgradeable } from "./Gateway.sol";

contract GatewayDebug is GatewayUpgradeable {
    function mockProceedWithdraw(bytes16 graphId) external {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        withdrawData.status = WithdrawStatus.Processing;
    }
}
