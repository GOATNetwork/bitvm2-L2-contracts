// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {PegBTC} from "../../src/PegBTC.sol";

contract DeployPegBTC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address gatewayProxy = vm.envAddress("GATEWAY_PROXY_ADDR");

        vm.startBroadcast(deployerPrivateKey);

        PegBTC pegBTC = new PegBTC(gatewayProxy);
        console.log("PegBTC contract address: ", address(pegBTC));

        vm.stopBroadcast();
    }
}
