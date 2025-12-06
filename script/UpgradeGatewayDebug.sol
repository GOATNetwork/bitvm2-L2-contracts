pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {GatewayDebug} from "../src/GatewayDebug.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeGateway is Script {
    address public sender;
    address public proxyAdmin;
    address payable public gateway;

    function setUp() public virtual {
        proxyAdmin = vm.envAddress("PROXYADMIN_ADDR");
        gateway = payable(vm.envAddress("GATEWAY_ADDR"));
    }

    function run() public {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        sender = vm.createWallet(senderPrivateKey).addr;
        vm.startBroadcast(senderPrivateKey);
        upgrade();
        vm.stopBroadcast();
    }

    function upgrade() public {
        GatewayDebug gatewayImpl = new GatewayDebug();
        ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(gateway), address(gatewayImpl), "");
        console.log("new Gateway impl contract address: ", address(gatewayImpl));
    }
}
