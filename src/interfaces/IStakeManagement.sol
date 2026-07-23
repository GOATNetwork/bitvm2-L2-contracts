// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IStakeManagement {
    event StakeDeposited(address indexed operator, uint256 amount);
    event StakeWithdrawn(address indexed operator, uint256 amount);
    event StakeLocked(address indexed operator, uint256 amount);
    event StakeUnlocked(address indexed operator, uint256 amount);
    event StakeSlashed(address indexed operator, uint256 amount);
    event PubkeyRegistered(address indexed operator, bytes32 pubkey);
    event PubkeyUnregistered(address indexed operator, bytes32 pubkey);

    function stakeTokenAddress() external view returns (address);
    function pubkeyToAddress(bytes32 pubkey) external view returns (address); // XOnlyPubkey
    function stakeOf(address operator) external view returns (uint256);
    function lockedStakeOf(address operator) external view returns (uint256);
    function slashStake(address operator, uint256 amount) external;
    function lockStake(address operator, uint256 amount) external;
    function unlockStake(address operator, uint256 amount) external;
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function getRegisterPubkeyDigest(address operator) external view returns (bytes32);
    function registerPubkey(bytes32 pubkey, bytes1 pubkeyPrefix, bytes calldata signature) external;
    function unregisterPubkey() external;
}
