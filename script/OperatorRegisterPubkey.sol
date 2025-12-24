// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {GatewayUpgradeable} from "../src/Gateway.sol";
import {StakeManagement} from "../src/StakeManagement.sol";

contract OperatorRegisterPubkey is Script {
    function run() public {
        uint256 operatorPrivateKey = vm.envUint("PRIVATE_KEY");
        address operator = vm.addr(operatorPrivateKey);
        
        address gatewayAddr = vm.envAddress("GATEWAY_ADDR");
        bytes32 pubkey = vm.envBytes32("PUBKEY");

        console.log("Operator:", operator);
        console.log("Gateway:", gatewayAddr);
        console.log("Pubkey:", vm.toString(pubkey));

        vm.startBroadcast(operatorPrivateKey);
        address stakeManagementAddr = address(GatewayUpgradeable(payable(gatewayAddr)).stakeManagement());
        console.log("StakeManagement:", stakeManagementAddr);

        StakeManagement(stakeManagementAddr).registerPubkey(pubkey);
        
        console.log("Pubkey registered successfully");

        vm.stopBroadcast();
    }
}
