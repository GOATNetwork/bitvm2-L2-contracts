// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {GatewayUpgradeable} from "../../src/Gateway.sol";
import {IPegBTC} from "../../src/interfaces/IPegBTC.sol";
import {IBitcoinSPV} from "../../src/interfaces/IBitcoinSPV.sol";
import {
    ICommitteeManagement
} from "../../src/interfaces/ICommitteeManagement.sol";
import {IStakeManagement} from "../../src/interfaces/IStakeManagement.sol";
import {UpgradeableProxy} from "../../src/UpgradeableProxy.sol";

contract DeployGateway is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.createWallet(deployerPrivateKey).addr;

        address pegBTC = vm.envAddress("PEGBTC_ADDR");
        address bitcoinSPV = vm.envAddress("BITCOINSPV_ADDR");
        address committeeProxy = vm.envAddress("COMMITTEE_PROXY_ADDR");
        address stakeProxy = vm.envAddress("STAKE_PROXY_ADDR");

        vm.startBroadcast(deployerPrivateKey);

        GatewayUpgradeable gatewayImpl = new GatewayUpgradeable();
        console.log(
            "Gateway implementation contract address: ",
            address(gatewayImpl)
        );

        bytes memory initCalldata = abi.encodeWithSelector(
            GatewayUpgradeable.initialize.selector,
            IPegBTC(pegBTC),
            IBitcoinSPV(bitcoinSPV),
            ICommitteeManagement(committeeProxy),
            IStakeManagement(stakeProxy)
        );

        UpgradeableProxy gatewayProxy = new UpgradeableProxy(
            address(gatewayImpl),
            deployer,
            initCalldata
        );
        console.log("Gateway proxy contract address: ", address(gatewayProxy));

        vm.stopBroadcast();
    }
}
