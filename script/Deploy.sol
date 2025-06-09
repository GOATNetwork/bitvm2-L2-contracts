pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IPegBTC} from "../src/interfaces/IPegBTC.sol";
import {IBitcoinSPV} from "../src/interfaces/IBitcoinSPV.sol";

import {GatewayUpgradeable} from "../src/Gateway.sol";
import {PegBTC} from "../src/PegBTC.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";

contract TaskTest is Script {
    address public deployer;

    address public relayer;
    address public bitcoinSPV;

    function setUp() public virtual {
        relayer = vm.envAddress("RELAYER_ADDR");
        bitcoinSPV = vm.envAddress("BITCOIN_CONTRACT");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.createWallet(deployerPrivateKey).addr;
        vm.startBroadcast(deployerPrivateKey);

        // deploy();
        deployLogic();

        vm.stopBroadcast();
    }

    function deploy() public {
        // deploy contracts
        PegBTC pegBTC = new PegBTC(deployer);

        GatewayUpgradeable gateway = new GatewayUpgradeable(address(pegBTC), bitcoinSPV);
        UpgradeableProxy proxy = new UpgradeableProxy(address(gateway), deployer, "");
        gateway = GatewayUpgradeable(payable(proxy));
        // pegBTC.transferOwnership(address(gateway));

        console.log("Gateway contract address: ", address(gateway));
    }

    function deployLogic() public {
        address pegBTC = vm.envAddress("PEG_BTC");
        GatewayUpgradeable gateway = new GatewayUpgradeable(pegBTC, bitcoinSPV);
        console.log("Gateway logic address: ", address(gateway));
    }
}
