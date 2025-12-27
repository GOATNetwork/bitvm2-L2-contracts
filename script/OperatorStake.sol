pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakeManagement} from "../src/StakeManagement.sol";
import {IStakeManagement} from "../src/interfaces/IStakeManagement.sol";
import {GatewayUpgradeable} from "../src/Gateway.sol";

/*
# Operator stake and lock

Stake PBTC as an operator and lock it via StakeManagement fetched from the Gateway.

Env vars:
- GATEWAY_ADDR: address of the Gateway proxy
- PRIVATE_KEY: operator's private key
- STAKE_AMOUNT: amount of PBTC to stake (wei)
- LOCK_AMOUNT: amount to lock (wei), optional; defaults to STAKE_AMOUNT when omitted or 0

Example:

```sh
export GATEWAY_ADDR=0x...
export PRIVATE_KEY=...
export STAKE_AMOUNT=60000000000000000
export LOCK_AMOUNT=60000000000000000 # optional
```
*/
contract OperatorStake is Script {
    address public operator;
    address public stakeManagementAddr;
    address public gatewayAddr;

    uint256 public stakeAmount;
    uint256 public lockAmount;

    function setUp() public virtual {
        // Read Gateway address from env, then fetch StakeManagement from it
        gatewayAddr = vm.envAddress("GATEWAY_ADDR");
        IStakeManagement sm = GatewayUpgradeable(payable(gatewayAddr)).stakeManagement();
        stakeManagementAddr = address(sm);

        stakeAmount = vm.envUint("STAKE_AMOUNT");
        uint256 lockAmt = vm.envOr("LOCK_AMOUNT", uint256(0));
        lockAmount = lockAmt == 0 ? stakeAmount : lockAmt;
    }

    function run() public {
        uint256 operatorPk = vm.envUint("PRIVATE_KEY");
        operator = vm.createWallet(operatorPk).addr;
        console.log("operator:", operator);
        console.log("Gateway:", gatewayAddr);
        console.log("StakeManagement:", stakeManagementAddr);

        vm.startBroadcast(operatorPk);
        _stakeAndLock();
        vm.stopBroadcast();
    }

    function _stakeAndLock() internal {
        // Resolve token from StakeManagement
        address tokenAddr = IStakeManagement(stakeManagementAddr).stakeTokenAddress();
        IERC20 token = IERC20(tokenAddr);

        console.log("stake token:", tokenAddr);
        console.log("stake amount:", stakeAmount);
        console.log("lock amount:", lockAmount);

        // Check balance for a friendly message (not a hard requirement here)
        uint256 bal = token.balanceOf(operator);
        console.log("operator balance:", bal);

        // Approve if needed
        uint256 allowance = token.allowance(operator, stakeManagementAddr);
        if (allowance < stakeAmount) {
            // Approve exactly the shortfall to minimize allowance; simple path: set to stakeAmount
            // If an allowance already exists, some ERC20s require resetting to 0 first; PegBTC is standard OpenZeppelin ERC20, so direct set is fine.
            bool ok = token.approve(stakeManagementAddr, stakeAmount);
            require(ok, "approve failed");
            console.log("approved:", stakeAmount);
        } else {
            console.log("sufficient allowance, skipping approve");
        }

        // Stake
        StakeManagement(stakeManagementAddr).stake(stakeAmount);
        console.log("staked");

        // Lock if requested (> 0)
        if (lockAmount > 0) {
            StakeManagement(stakeManagementAddr).lockStake(operator, lockAmount);
            console.log("locked");
        }
    }
}
