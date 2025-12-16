// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IStakeManagement.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakeManagement is IStakeManagement, Initializable {
    IERC20 public stakeToken;
    address public gatewayAddress;

    mapping(address => uint256) private stakes;
    mapping(address => uint256) private lockedStakes;

    mapping(address => bytes32) public addressToPubkey; // XOnlyPubkey
    mapping(bytes32 => address) public pubkeyToAddress;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 _stakeToken,
        address _gatewayAddress
    ) public initializer {
        require(address(_stakeToken) != address(0), "stake token zero");
        require(_gatewayAddress != address(0), "gateway zero");
        stakeToken = _stakeToken;
        gatewayAddress = _gatewayAddress;
    }

    function stakeTokenAddress() external view override returns (address) {
        return address(stakeToken);
    }

    function stakeOf(
        address operator
    ) external view override returns (uint256) {
        return stakes[operator];
    }

    function lockedStakeOf(
        address operator
    ) external view override returns (uint256) {
        return lockedStakes[operator];
    }

    function slashStake(address operator, uint256 amount) external override {
        require(stakes[operator] >= amount, "insufficient stake to slash");
        if (lockedStakes[operator] > amount) {
            lockedStakes[operator] -= amount;
        } else {
            lockedStakes[operator] = 0;
        }
        stakes[operator] -= amount;
        // Transfer the slashed tokens to the gateway which redistributes rewards
        require(
            stakeToken.transfer(gatewayAddress, amount),
            "stake transfer failed"
        );
    }

    function lockStake(address operator, uint256 amount) external override {
        require(
            msg.sender == operator || msg.sender == gatewayAddress,
            "only operator or gateway can lock stake"
        );
        require(
            stakes[operator] - lockedStakes[operator] >= amount,
            "insufficient available stake to lock"
        );
        lockedStakes[operator] += amount;
    }

    function unlockStake(address operator, uint256 amount) external override {
        require(msg.sender == gatewayAddress, "only gateway can unlock stake");
        if (lockedStakes[operator] >= amount) {
            lockedStakes[operator] -= amount;
        } else {
            lockedStakes[operator] = 0;
        }
    }

    function stake(uint256 amount) external {
        require(
            stakeToken.transferFrom(msg.sender, address(this), amount),
            "stake transfer failed"
        );
        stakes[msg.sender] += amount;
    }

    function unstake(uint256 amount) external {
        require(
            stakes[msg.sender] - lockedStakes[msg.sender] >= amount,
            "insufficient available stake to unstake"
        );
        stakes[msg.sender] -= amount;
        require(
            stakeToken.transfer(msg.sender, amount),
            "stake transfer failed"
        );
    }

    function registerPubkey(bytes32 pubkey) external {
        require(
            addressToPubkey[msg.sender] == bytes32(0),
            "already registered a pubkey"
        );
        require(
            pubkeyToAddress[pubkey] == address(0),
            "pubkey already registered by another address"
        );
        addressToPubkey[msg.sender] = pubkey;
        pubkeyToAddress[pubkey] = msg.sender;
    }

    uint256[50] private __gap;
}
