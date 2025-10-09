pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IPegBTC} from "../src/interfaces/IPegBTC.sol";
import {IBitcoinSPV} from "../src/interfaces/IBitcoinSPV.sol";

import {GatewayUpgradeable} from "../src/Gateway.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeGateway is Script {
    address public deployer;
    address public proxyAdmin;
    address payable public gateway;

    function setUp() public virtual {
        proxyAdmin = vm.envAddress("PROXYADMIN_ADDR");
        gateway = payable(vm.envAddress("GATEWAY_ADDR"));
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.createWallet(deployerPrivateKey).addr;
        vm.startBroadcast(deployerPrivateKey);
        upgrade();
        vm.stopBroadcast();
    }

    function upgrade() public {
        GatewayUpgradeable gatewayImpl = new GatewayUpgradeable();
        ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(gateway), address(gatewayImpl), "");
        console.log("new Gateway impl contract address: ", address(gatewayImpl));
    }
}
