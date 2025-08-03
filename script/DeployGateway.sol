pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IPegBTC} from "../src/interfaces/IPegBTC.sol";
import {IBitcoinSPV} from "../src/interfaces/IBitcoinSPV.sol";

import {GatewayUpgradeable} from "../src/Gateway.sol";
import {PegBTC} from "../src/PegBTC.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";

contract DeployGateway is Script {
    address public deployer;
    address public gatewayOwner;
    address public relayer;
    address public bitcoinSPV;
    address public pegBTC;
    bytes public relayerPeerId;

    function setUp() public virtual {
        gatewayOwner = vm.envAddress("GATEWAY_OWNER");
        relayer = vm.envAddress("RELAYER_ADDR");
        relayerPeerId = vm.envBytes("RELAYER_PEERID");
        bitcoinSPV = vm.envAddress("BITCOINSPV_ADDR");
        pegBTC = vm.envAddress("PEGBTC_ADDR");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.createWallet(deployerPrivateKey).addr;
        console.log("deployer address: ", deployer);
        vm.startBroadcast(deployerPrivateKey);
        deploy();
        vm.stopBroadcast();
    }

    function deploy() public {
        // deploy contracts
        GatewayUpgradeable gateway = new GatewayUpgradeable(pegBTC, bitcoinSPV);
        UpgradeableProxy proxy = new UpgradeableProxy(address(gateway), deployer, "");
        gateway = GatewayUpgradeable(payable(proxy));
        gateway.initialize(gatewayOwner, relayer, relayerPeerId);
        console.log("Gateway contract address: ", address(gateway));
    }
}
