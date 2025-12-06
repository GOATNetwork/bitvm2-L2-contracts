// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IPegBTC} from "../src/interfaces/IPegBTC.sol";
import {GatewayUpgradeable} from "../src/Gateway.sol";
import {Converter} from "../src/libraries/Converter.sol";

/*
	Script: approve PegBTC for the Gateway (if needed) and call Gateway.initWithdraw(instanceId, graphId).
    Required env vars:
	- PRIVATE_KEY:    uint256 private key to broadcast from (operator)
	- GATEWAY_ADDR:   address of deployed Gateway (proxy)
    - INSTANCE_ID:    bytes16 hex 
    - GRAPH_ID:       bytes16 hex 

*/
contract InitWithdraw is Script {
    function run() external {
        // Load inputs
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address gatewayAddr = vm.envAddress("GATEWAY_ADDR");

        // Parse ids directly as bytes and coerce to bytes16
        bytes memory instanceRaw = vm.envBytes("INSTANCE_ID");
        bytes memory graphRaw = vm.envBytes("GRAPH_ID");
        require(instanceRaw.length == 16, "INSTANCE_ID must be 16 bytes hex");
        require(graphRaw.length == 16, "GRAPH_ID must be 16 bytes hex");
        bytes16 instanceId;
        bytes16 graphId;
        assembly {
            instanceId := mload(add(instanceRaw, 0x20))
            graphId := mload(add(graphRaw, 0x20))
        }

        GatewayUpgradeable gateway = GatewayUpgradeable(gatewayAddr);

        address pegBtcAddr = address(gateway.pegBTC());
        IPegBTC peg = IPegBTC(pegBtcAddr);

        // Read pegin data to compute the exact lock amount in PegBTC
        GatewayUpgradeable.PeginData memory pegin = gateway.getPeginData(instanceId);
        require(pegin.peginAmountSats > 0, "pegin not found or amount=0");
        uint256 lockAmount = Converter.amountFromSats(pegin.peginAmountSats);

        // derive sender address from private key in a view-only way
        address operator = vm.addr(pk);
        console.log("\ninstanceId:", vm.toString(instanceId));
        console.log("\ngraphId:", vm.toString(graphId));
        console.log("\nOperator address:", operator);

        // Check allowance/balance and approve if needed
        uint256 allowance = peg.allowance(operator, gatewayAddr);
        uint256 balance = peg.balanceOf(operator);
        require(balance >= lockAmount, "insufficient PegBTC balance for lock");

        vm.startBroadcast(pk);
        if (allowance < lockAmount) {
            // set a generous allowance once to avoid repeated approvals
            bool ok = peg.approve(gatewayAddr, type(uint256).max);
            require(ok, "\napprove failed");
            console.log("\nApproved PegBTC for Gateway:");
            console.log("  spender:", gatewayAddr);
            console.log("  amount:", type(uint256).max);
        }

        // Call initWithdraw
        gateway.initWithdraw(instanceId, graphId);
        vm.stopBroadcast();

        console.log("\ninitWithdraw sent:");
    }
}
