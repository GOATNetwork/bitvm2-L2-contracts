// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakeManagement} from "../../src/StakeManagement.sol";
import {UpgradeableProxy} from "../../src/UpgradeableProxy.sol";

contract DeployStakeManagement is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.createWallet(deployerPrivateKey).addr;
        address gatewayProxy = vm.envAddress("GATEWAY_PROXY_ADDR");
        address pegBTC = vm.envAddress("PEGBTC_ADDR");

        vm.startBroadcast(deployerPrivateKey);

        StakeManagement stakeImpl = new StakeManagement();
        console.log(
            "StakeManagement implementation contract address: ",
            address(stakeImpl)
        );

        bytes memory stakeInitData = abi.encodeWithSelector(
            StakeManagement.initialize.selector,
            IERC20(pegBTC),
            gatewayProxy
        );
        UpgradeableProxy stakeProxy = new UpgradeableProxy(
            address(stakeImpl),
            deployer,
            stakeInitData
        );
        console.log(
            "StakeManagement proxy contract address: ",
            address(stakeProxy)
        );

        vm.stopBroadcast();
    }
}
