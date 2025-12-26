// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {GatewayUpgradeable} from "./Gateway.sol";
import {CommitteeManagement} from "./CommitteeManagement.sol";
import {StakeManagement} from "./StakeManagement.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract GatewayDebug is GatewayUpgradeable {
    function mockProceedWithdraw(bytes16 graphId) external onlyCommittee {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        withdrawData.status = WithdrawStatus.Processing;
    }

    function debugMintPegBTC(address to, uint256 amount) external onlyCommittee {
        pegBTC.mint(to, amount);
    }

    // function debugUpdateCommitteeManagement(address newCommitteeManagement) external onlyCommittee {
    //     committeeManagement = CommitteeManagement(newCommitteeManagement);
    // }

    // function debugUpdateStakeManagement(address newStakeManagement) external onlyCommittee {
    //     stakeManagement = StakeManagement(newStakeManagement);
    // }

    // function debugSetBitvmPolicy(
    //     uint64 _minChallengeAmountSats,
    //     uint64 _minPeginFeeSats,
    //     uint64 _peginFeeRate,
    //     uint64 _minOperatorRewardSats,
    //     uint64 _operatorRewardRate,
    //     uint64 _minStakeAmount,
    //     uint64 _minChallengerReward,
    //     uint64 _minDisproverReward,
    //     uint64 _minSlashAmount
    // ) external onlyCommittee {
    //     require(_peginFeeRate <= rateMultiplier, "peginFeeRate too large");
    //     require(_operatorRewardRate <= rateMultiplier, "operatorRewardRate too large");

    //     minChallengeAmountSats = _minChallengeAmountSats;
    //     minPeginFeeSats = _minPeginFeeSats;
    //     peginFeeRate = _peginFeeRate;
    //     minOperatorRewardSats = _minOperatorRewardSats;
    //     operatorRewardRate = _operatorRewardRate;

    //     minStakeAmount = _minStakeAmount;
    //     minChallengerReward = _minChallengerReward;
    //     minDisproverReward = _minDisproverReward;
    //     minSlashAmount = _minSlashAmount;
    // }

    // function debugClearData() external onlyCommittee {
    //     for (uint256 i = 0; i < instanceIds.length; i++) {
    //         bytes16 instanceId = instanceIds[i];

    //         bytes16[] storage graphIds = instanceIdToGraphIds[instanceId];
    //         for (uint256 j = 0; j < graphIds.length; j++) {
    //             bytes16 graphId = graphIds[j];
    //             delete graphDataMap[graphId];
    //             delete withdrawDataMap[graphId];
    //         }

    //         delete instanceIdToGraphIds[instanceId];
    //         delete peginDataMap[instanceId];
    //     }

    //     delete instanceIds;
    // }

    function debugCancelWithdraw(bytes16 graphId) external onlyOperator(graphId) {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        PeginDataInner storage peginData = peginDataMap[withdrawData.instanceId];
        require(withdrawData.status == WithdrawStatus.Initialized, "x");
        withdrawData.status = WithdrawStatus.Canceled;
        pegBTC.transfer(msg.sender, withdrawData.lockAmount);
        peginData.status = PeginStatus.Withdrawbale;

        emit CancelWithdraw(withdrawData.instanceId, graphId, msg.sender);
    }
}

contract CommitteeManagementDebug is CommitteeManagement {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;


    modifier onlyCommittee() {
        require(isOwner[msg.sender], "only committee member can call");
        _;
    }

    function debugUpdateCommittee(address[] calldata newCommittee, uint256 newRequired) external onlyCommittee {
        _applyOwners(newCommittee, newRequired);
    }

    function debugAddWatchtower(bytes32 watchtower) external onlyCommittee {
        watchtowerList.add(watchtower);
    }

    function debugRemoveWatchtower(bytes32 watchtower) external onlyCommittee {
        watchtowerList.remove(watchtower);
    }

    function debugAddAuthorizedCaller(address caller) external onlyCommittee {
        authorizedCallers.add(caller);
    }

    function debugRemoveAuthorizedCaller(address caller) external onlyCommittee {
        authorizedCallers.remove(caller);
    }

    function debugRegisterPeerId(address member, bytes calldata peerId) external onlyCommittee {
        require(isOwner[member], "Not a committee member");

        // Clear previous index if existed
        bytes memory prev = committeePeerId[member];
        if (prev.length != 0) {
            bytes32 prevHash = keccak256(prev);
            if (peerIdOwnerByHash[prevHash] == member) {
                delete peerIdOwnerByHash[prevHash];
            }
        }

        bytes32 h = keccak256(peerId);
        address current = peerIdOwnerByHash[h];
        require(current == address(0) || current == member, "peerId already registered by another member");

        committeePeerId[member] = peerId;
        peerIdOwnerByHash[h] = member;
    }
}
