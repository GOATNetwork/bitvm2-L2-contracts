// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {GatewayUpgradeable} from "../src/Gateway.sol";
import {IGateway} from "../src/interfaces/IGateway.sol";

/*
    Script: List instances from the Gateway.
    Required env vars:
    - GATEWAY_ADDR:           address of deployed Gateway (proxy)
    - START_INDEX:            (optional) uint256 start index for listing (default: 0)
    - END_INDEX:              (optional) uint256 end index for listing (default: max)
    - FILTER_PEGIN_STATUS:    (optional) int256 filter by pegin status (default: -1 for all)
    - FILTER_WITHDRAW_STATUS: (optional) int256 filter by withdraw status (default: -1 for all)
*/
contract DebugListInstance is Script {
    GatewayUpgradeable gateway;
    int256 filterPeginStatus;
    int256 filterWithdrawStatus;

    function run() public {
        address gatewayAddr = vm.envAddress("GATEWAY_ADDR");
        gateway = GatewayUpgradeable(gatewayAddr);
        
        console.log("Listing instances for Gateway at:", gatewayAddr);

        uint256 startIndex = vm.envOr("START_INDEX", uint256(0));
        uint256 endIndex = vm.envOr("END_INDEX", type(uint256).max);
        
        filterPeginStatus = vm.envOr("FILTER_PEGIN_STATUS", int256(-1));
        filterWithdrawStatus = vm.envOr("FILTER_WITHDRAW_STATUS", int256(-1));

        uint256 i = startIndex;
        while (i <= endIndex) {
            try gateway.instanceIds(i) returns (bytes16 instanceId) {
                listInstance(i, instanceId);
                i++;
            } catch {
                break;
            }
        }
    }

    function getPeginStatusString(uint256 status) internal pure returns (string memory) {
        if (status == uint256(IGateway.PeginStatus.None)) return "None";
        if (status == uint256(IGateway.PeginStatus.Pending)) return "Pending";
        if (status == uint256(IGateway.PeginStatus.Withdrawbale)) return "Withdrawbale";
        if (status == uint256(IGateway.PeginStatus.Processing)) return "Processing";
        if (status == uint256(IGateway.PeginStatus.Locked)) return "Locked";
        if (status == uint256(IGateway.PeginStatus.Claimed)) return "Claimed";
        if (status == uint256(IGateway.PeginStatus.Discarded)) return "Discarded";
        return "Unknown";
    }

    function getWithdrawStatusString(uint256 status) internal pure returns (string memory) {
        if (status == uint256(IGateway.WithdrawStatus.None)) return "None";
        if (status == uint256(IGateway.WithdrawStatus.Processing)) return "Processing";
        if (status == uint256(IGateway.WithdrawStatus.Initialized)) return "Initialized";
        if (status == uint256(IGateway.WithdrawStatus.Canceled)) return "Canceled";
        if (status == uint256(IGateway.WithdrawStatus.Complete)) return "Complete";
        if (status == uint256(IGateway.WithdrawStatus.Disproved)) return "Disproved";
        return "Unknown";
    }

    function listInstance(uint256 index, bytes16 instanceId) internal view {
        // Get Pegin Status
        (bool success, bytes memory data) = address(gateway).staticcall(
            abi.encodeWithSelector(gateway.peginDataMap.selector, instanceId)
        );
        
        uint256 statusVal;
        bool statusFetched = false;
        if (success && data.length >= 32) {
            statusVal = abi.decode(data, (uint256));
            statusFetched = true;
        }

        if (filterPeginStatus != -1) {
            if (!statusFetched || int256(statusVal) != filterPeginStatus) {
                return;
            }
        }

        console.log("--------------------------------------------------");
        console.log("Index:", index);
        console.log("Instance ID:");
        console.logBytes16(instanceId);
        
        if (statusFetched) {
            console.log("Pegin Status:", getPeginStatusString(statusVal));
        } else {
            console.log("Failed to fetch Pegin Status");
        }

        // List graphs
        uint256 j = 0;
        while (true) {
            try gateway.instanceIdToGraphIds(instanceId, j) returns (bytes16 graphId) {
                listGraph(graphId);
                j++;
            } catch {
                break;
            }
        }
    }

    function listGraph(bytes16 graphId) internal view {
        // Get Withdraw Status
        (bool success, bytes memory data) = address(gateway).staticcall(
            abi.encodeWithSelector(gateway.withdrawDataMap.selector, graphId)
        );

        uint256 statusVal;
        bool statusFetched = false;
        if (success && data.length >= 32) {
             statusVal = abi.decode(data, (uint256));
             statusFetched = true;
        }

        if (filterWithdrawStatus != -1) {
            if (!statusFetched || int256(statusVal) != filterWithdrawStatus) {
                return;
            }
        }

        console.log("  Graph ID:");
        console.logBytes16(graphId);

        if (statusFetched) {
             console.log("    Withdraw Status:", getWithdrawStatusString(statusVal));
        } else {
             console.log("    Failed to fetch Withdraw Status");
        }
    }
}