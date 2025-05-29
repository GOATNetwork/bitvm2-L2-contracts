// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IBitcoinSPV} from "./interfaces/IBitcoinSPV.sol";
import {IPegBTC} from "./interfaces/IPegBTC.sol";
import {Converter} from "./libraries/Converter.sol";
import {BitvmTxParser} from "./libraries/BitvmTxParser.sol";
import {MerkleProof} from "./libraries/MerkleProof.sol";
import {BitvmPolicy} from "./libraries/BitvmPolicy.sol";

contract GatewayUpgradeable is OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    event BridgeIn(address indexed depositorAddress, bytes16 indexed instanceId, uint64 indexed peginAmountSats);
    event InitWithdraw(
        bytes16 indexed instanceId, bytes16 indexed graphId, address indexed operatorAddress, uint64 withdrawAmountSats
    );
    event CancelWithdraw(bytes16 indexed instanceId, bytes16 indexed graphId, address indexed triggerAddress);
    event ProceedWithdraw(bytes16 indexed instanceId, bytes16 indexed graphId, bytes32 kickoffTxid);
    event WithdrawHappyPath(bytes16 indexed instanceId, bytes16 indexed graphId, bytes32 take1Txid);
    event WithdrawUnhappyPath(bytes16 indexed instanceId, bytes16 indexed graphId, bytes32 take2Txid);
    event WithdrawDisproved(
        bytes16 indexed instanceId,
        bytes16 indexed graphId,
        bytes32 disproveTxid,
        bytes32 challengeTxid,
        address indexed challengerAddress
    );

    enum PeginStatus {
        None,
        Processing,
        Withdrawbale,
        Locked,
        Claimed
    }
    enum WithdrawStatus {
        None,
        Processing,
        Initialized,
        Canceled,
        Complete,
        Disproved
    }

    struct PeginData {
        bytes32 peginTxid;
        PeginStatus status;
        uint64 peginAmount;
    }

    struct WithdrawData {
        bytes32 peginTxid;
        address operatorAddress;
        WithdrawStatus status;
        bytes16 instanceId;
        uint256 lockAmount;
    }

    struct OperatorData {
        uint64 stakeAmount;
        bytes1 operatorPubkeyPrefix;
        bytes32 operatorPubkey;
        bytes32 peginTxid;
        bytes32 preKickoffTxid;
        bytes32 kickoffTxid;
        bytes32 take1Txid;
        bytes32 assertInitTxid;
        bytes32[4] assertCommitTxids;
        bytes32 assertFinalTxid;
        bytes32 take2Txid;
    }

    IPegBTC public immutable pegBTC;
    IBitcoinSPV public immutable bitcoinSPV;

    address public relayer;
    bytes public relayerPeerId;
    uint64 public minStakeAmountSats;

    EnumerableSet.Bytes32Set private committeePeerId;
    EnumerableSet.Bytes32Set private operatorPeerId;

    mapping(bytes32 => bool) public peginTxUsed;
    mapping(bytes16 instanceId => PeginData) public peginDataMap;

    mapping(bytes16 graphId => bool) public operatorWithdrawn;
    mapping(bytes16 graphId => OperatorData) public operatorDataMap;
    mapping(bytes16 graphId => WithdrawData) public withdrawDataMap;

    bytes16[] public instanceIds;
    mapping(bytes16 instanceId => bytes16[] graphIds) public instanceIdToGraphIds;

    constructor(address _pegBTC, address _bitcoinSPV) {
        pegBTC = IPegBTC(_pegBTC);
        bitcoinSPV = IBitcoinSPV(_bitcoinSPV);
    }

    function initialize(address owner, address newRelayer, bytes calldata peerId) external initializer {
        __Ownable_init(owner);
        relayer = newRelayer;
        relayerPeerId = peerId;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "not relayer!");
        _;
    }

    modifier onlyOperator(bytes16 graphId) {
        require(withdrawDataMap[graphId].operatorAddress == msg.sender, "not operator!");
        _;
    }

    modifier onlyRelayerOrOperator(bytes16 graphId) {
        require(
            msg.sender == relayer || withdrawDataMap[graphId].operatorAddress == msg.sender, "not relayer or operator!"
        );
        _;
    }

    function setMinStakeAmountSats(uint64 _minStakeAmountSats) external onlyOwner {
        minStakeAmountSats = _minStakeAmountSats;
    }

    function setRelayer(address newRelayer, bytes calldata peerId) external onlyOwner {
        require(newRelayer != address(0), "invalid relayer");
        relayer = newRelayer;
        relayerPeerId = peerId;
    }

    function addCommitteePeerId(bytes calldata id) external onlyOwner {
        require(id.length > 0, "invalid id");
        bytes32 idHash = keccak256(id);
        committeePeerId.add(idHash);
    }

    function removeCommitteePeerId(bytes calldata id) external onlyOwner {
        bytes32 idHash = keccak256(id);
        require(committeePeerId.remove(idHash), "not committee");
    }

    function addOperatorPeerId(bytes calldata id) external onlyOwner {
        require(id.length > 0, "invalid id");
        bytes32 idHash = keccak256(id);
        operatorPeerId.add(idHash);
    }

    function removeOperatorPeerId(bytes calldata id) external onlyOwner {
        bytes32 idHash = keccak256(id);
        require(operatorPeerId.remove(idHash), "not operator");
    }

    function isCommittee(bytes calldata id) external view returns (bool) {
        bytes32 idHash = keccak256(id);
        return committeePeerId.contains(idHash);
    }

    function getCommitteeLength() external view returns (uint256) {
        return committeePeerId.length();
    }

    function isOperator(bytes calldata id) external view returns (bool) {
        bytes32 idHash = keccak256(id);
        return operatorPeerId.contains(idHash);
    }

    function getOperatorLength() external view returns (uint256) {
        return operatorPeerId.length();
    }

    function getBlockHash(uint256 height) external view returns (bytes32) {
        return bitcoinSPV.blockHash(height);
    }

    function getGraphIdsByInstanceId(bytes16 instanceId) external view returns (bytes16[] memory) {
        return instanceIdToGraphIds[instanceId];
    }

    function getInitializedInstanceIds()
        external
        view
        returns (bytes16[] memory retInstanceIds, bytes16[] memory retGraphIds)
    {
        uint256 count;
        // First pass to count matching entries
        for (uint256 i = 0; i < instanceIds.length; ++i) {
            bytes16 instanceId = instanceIds[i];
            bytes16[] memory graphIds = instanceIdToGraphIds[instanceId];
            for (uint256 j = 0; j < graphIds.length; ++j) {
                bytes16 graphId = graphIds[j];
                if (withdrawDataMap[graphId].status == WithdrawStatus.Initialized) {
                    count++;
                }
            }
        }

        // Second pass to populate return arrays
        retInstanceIds = new bytes16[](count);
        retGraphIds = new bytes16[](count);
        uint256 index;
        for (uint256 i = 0; i < instanceIds.length; ++i) {
            bytes16 instanceId = instanceIds[i];
            bytes16[] memory graphIds = instanceIdToGraphIds[instanceId];
            for (uint256 j = 0; j < graphIds.length; ++j) {
                bytes16 graphId = graphIds[j];
                if (withdrawDataMap[graphId].status == WithdrawStatus.Initialized) {
                    retInstanceIds[index] = instanceId;
                    retGraphIds[index] = graphId;
                    index++;
                }
            }
        }
    }

    function getInstanceIdsByPubKey(bytes32 operatorPubkey)
        external
        view
        returns (bytes16[] memory retInstanceIds, bytes16[] memory retGraphIds)
    {
        uint256 count;
        // First pass to count matching entries
        for (uint256 i = 0; i < instanceIds.length; ++i) {
            bytes16 instanceId = instanceIds[i];
            bytes16[] memory graphIds = instanceIdToGraphIds[instanceId];
            for (uint256 j = 0; j < graphIds.length; ++j) {
                bytes16 graphId = graphIds[j];
                if (
                    operatorDataMap[graphId].operatorPubkey == operatorPubkey
                        && withdrawDataMap[graphId].status == WithdrawStatus.Initialized
                ) {
                    count++;
                }
            }
        }

        // Second pass to populate return arrays
        retInstanceIds = new bytes16[](count);
        retGraphIds = new bytes16[](count);
        uint256 index;
        for (uint256 i = 0; i < instanceIds.length; ++i) {
            bytes16 instanceId = instanceIds[i];
            bytes16[] memory graphIds = instanceIdToGraphIds[instanceId];
            for (uint256 j = 0; j < graphIds.length; ++j) {
                bytes16 graphId = graphIds[j];
                if (
                    operatorDataMap[graphId].operatorPubkey == operatorPubkey
                        && withdrawDataMap[graphId].status == WithdrawStatus.Initialized
                ) {
                    retInstanceIds[index] = instanceId;
                    retGraphIds[index] = graphId;
                    index++;
                }
            }
        }
    }

    function getWithdrawableInstances(bytes32 operatorPubkey)
        external
        view
        returns (bytes16[] memory retInstanceIds, bytes16[] memory retGraphIds, uint64[] memory retPeginAmounts)
    {
        uint256 count;

        // First pass to count
        for (uint256 i = 0; i < instanceIds.length; ++i) {
            bytes16 instanceId = instanceIds[i];
            bytes16[] memory graphIds = instanceIdToGraphIds[instanceId];
            for (uint256 j = 0; j < graphIds.length; ++j) {
                bytes16 graphId = graphIds[j];
                WithdrawData storage withdrawData = withdrawDataMap[graphId];
                PeginData storage peginData = peginDataMap[instanceId];
                if (
                    operatorDataMap[graphId].operatorPubkey == operatorPubkey
                        && (withdrawData.status == WithdrawStatus.None || withdrawData.status == WithdrawStatus.Canceled)
                        && peginData.status == PeginStatus.Withdrawbale && !operatorWithdrawn[graphId]
                ) {
                    count++;
                }
            }
        }

        // Second pass to collect
        retInstanceIds = new bytes16[](count);
        retGraphIds = new bytes16[](count);
        retPeginAmounts = new uint64[](count);
        uint256 index;

        for (uint256 i = 0; i < instanceIds.length; ++i) {
            bytes16 instanceId = instanceIds[i];
            bytes16[] memory graphIds = instanceIdToGraphIds[instanceId];
            for (uint256 j = 0; j < graphIds.length; ++j) {
                bytes16 graphId = graphIds[j];
                WithdrawData storage withdrawData = withdrawDataMap[graphId];
                PeginData storage peginData = peginDataMap[instanceId];
                if (
                    operatorDataMap[graphId].operatorPubkey == operatorPubkey
                        && (withdrawData.status == WithdrawStatus.None || withdrawData.status == WithdrawStatus.Canceled)
                        && peginData.status == PeginStatus.Withdrawbale && !operatorWithdrawn[graphId]
                ) {
                    retInstanceIds[index] = instanceId;
                    retGraphIds[index] = graphId;
                    retPeginAmounts[index] = peginData.peginAmount;
                    index++;
                }
            }
        }
    }

    function postPeginData(
        bytes16 instanceId,
        BitvmTxParser.BitcoinTx calldata rawPeginTx,
        MerkleProof.BitcoinTxProof calldata peginProof
    ) external onlyRelayer {
        (bytes32 peginTxid, uint64 peginAmountSats, address depositorAddress) = BitvmTxParser.parsePegin(rawPeginTx);

        require(peginDataMap[instanceId].peginTxid == 0, "pegin tx already posted");
        // double spend check
        require(!peginTxUsed[peginTxid], "this pegin tx has already been posted");

        // validate pegin tx
        (bytes32 blockHash, bytes32 merkleRoot) = MerkleProof.parseBtcBlockHeader(peginProof.rawHeader);
        require(bitcoinSPV.blockHash(peginProof.height) == blockHash, "invalid header");
        require(MerkleProof.verifyMerkleProof(merkleRoot, peginProof.proof, peginTxid, peginProof.index), "unable to verify");

        // record pegin tx data
        peginTxUsed[peginTxid] = true;
        peginDataMap[instanceId] =
            PeginData({peginTxid: peginTxid, peginAmount: peginAmountSats, status: PeginStatus.Withdrawbale});
        instanceIds.push(instanceId);

        // mint pegBTC to user
        pegBTC.mint(depositorAddress, Converter.amountFromSats(peginAmountSats));

        emit BridgeIn(depositorAddress, instanceId, peginAmountSats);
    }

    function postOperatorData(bytes16 instanceId, bytes16 graphId, OperatorData calldata operatorData)
        public
        onlyRelayer
    {
        PeginData storage peginData = peginDataMap[instanceId];
        require(operatorData.peginTxid == peginData.peginTxid, "operator data pegin txid mismatch");
        require(BitvmPolicy.isValidStakeAmount(peginData.peginAmount, operatorData.stakeAmount), "insufficient stake amount");
        operatorDataMap[graphId] = operatorData;
        instanceIdToGraphIds[instanceId].push(graphId);
    }

    function postOperatorDataBatch(
        bytes16 instanceId,
        bytes16[] calldata graphIds,
        OperatorData[] calldata operatorData
    ) external onlyRelayer {
        require(graphIds.length == operatorData.length, "inputs length mismatch");
        for (uint256 i; i < graphIds.length; ++i) {
            postOperatorData(instanceId, graphIds[i], operatorData[i]);
        }
    }

    function initWithdraw(bytes16 instanceId, bytes16 graphId) external {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        require(
            withdrawData.status == WithdrawStatus.None || withdrawData.status == WithdrawStatus.Canceled,
            "invalid withdraw status"
        );
        PeginData storage peginData = peginDataMap[instanceId];
        require(peginData.status == PeginStatus.Withdrawbale, "not a withdrawable pegin tx");
        require(!operatorWithdrawn[graphId], "operator already used up withdraw chance");

        // lock the pegin utxo so others can not withdraw it
        peginData.status = PeginStatus.Locked;

        // lock operator's pegBTC
        uint256 lockAmount = Converter.amountFromSats(peginData.peginAmount);
        pegBTC.transferFrom(msg.sender, address(this), lockAmount);

        withdrawData.peginTxid = peginData.peginTxid;
        withdrawData.operatorAddress = msg.sender;
        withdrawData.status = WithdrawStatus.Initialized;
        withdrawData.instanceId = instanceId;
        withdrawData.lockAmount = lockAmount;

        emit InitWithdraw(instanceId, graphId, withdrawData.operatorAddress, peginData.peginAmount);
    }

    function cancelWithdraw(bytes16 graphId) external onlyRelayerOrOperator(graphId) {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        PeginData storage peginData = peginDataMap[withdrawData.instanceId];
        require(withdrawData.status == WithdrawStatus.Initialized, "invalid withdraw index: not at init stage");
        withdrawData.status = WithdrawStatus.Canceled;
        pegBTC.transfer(msg.sender, withdrawData.lockAmount);
        peginData.status = PeginStatus.Withdrawbale;

        emit CancelWithdraw(withdrawData.instanceId, graphId, msg.sender);
    }

    // post kickoff tx
    function proceedWithdraw(
        bytes16 graphId,
        BitvmTxParser.BitcoinTx calldata rawKickoffTx,
        MerkleProof.BitcoinTxProof calldata kickoffProof
    ) external onlyRelayerOrOperator(graphId) {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        bytes16 instanceId = withdrawData.instanceId;
        require(withdrawData.status == WithdrawStatus.Initialized, "invalid withdraw index: not at init stage");

        OperatorData storage operatorData = operatorDataMap[graphId];
        bytes32 kickoffTxid = BitvmTxParser.parseKickoffTx(rawKickoffTx);
        require(kickoffTxid == operatorData.kickoffTxid, "kickoff txid mismatch");
        (bytes32 blockHash, bytes32 merkleRoot) = MerkleProof.parseBtcBlockHeader(kickoffProof.rawHeader);
        require(bitcoinSPV.blockHash(kickoffProof.height) == blockHash, "invalid header");
        require(MerkleProof.verifyMerkleProof(merkleRoot, kickoffProof.proof, kickoffTxid, kickoffProof.index), "unable to verify");

        // once kickoff is braodcasted , operator will not be able to cancel withdrawal
        withdrawData.status = WithdrawStatus.Processing;
        operatorWithdrawn[graphId] = true;

        // burn pegBTC
        pegBTC.burn(withdrawData.lockAmount);

        emit ProceedWithdraw(instanceId, graphId, kickoffTxid);
    }

    function finishWithdrawHappyPath(
        bytes16 graphId,
        BitvmTxParser.BitcoinTx calldata rawTake1Tx,
        MerkleProof.BitcoinTxProof calldata take1Proof
    ) external onlyRelayerOrOperator(graphId) {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        bytes16 instanceId = withdrawData.instanceId;
        PeginData storage peginData = peginDataMap[instanceId];
        require(withdrawData.status == WithdrawStatus.Processing, "invalid withdraw index: not at processing stage");

        OperatorData storage operatorData = operatorDataMap[graphId];
        bytes32 take1Txid = BitvmTxParser.parseTake1Tx(rawTake1Tx);
        require(BitvmTxParser.parseTake1Tx(rawTake1Tx) == operatorData.take1Txid, "take1 txid mismatch");
        (bytes32 blockHash, bytes32 merkleRoot) = MerkleProof.parseBtcBlockHeader(take1Proof.rawHeader);
        require(bitcoinSPV.blockHash(take1Proof.height) == blockHash, "invalid header");
        require(MerkleProof.verifyMerkleProof(merkleRoot, take1Proof.proof, take1Txid, take1Proof.index), "unable to verify");

        peginData.status = PeginStatus.Claimed;
        withdrawData.status = WithdrawStatus.Complete;

        emit WithdrawHappyPath(instanceId, graphId, take1Txid);
    }

    function finishWithdrawUnhappyPath(
        bytes16 graphId,
        BitvmTxParser.BitcoinTx calldata rawTake2Tx,
        MerkleProof.BitcoinTxProof calldata take2Proof
    ) external onlyRelayerOrOperator(graphId) {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        bytes16 instanceId = withdrawData.instanceId;
        PeginData storage peginData = peginDataMap[instanceId];
        require(withdrawData.status == WithdrawStatus.Processing, "invalid withdraw index: not at processing stage");

        OperatorData storage operatorData = operatorDataMap[graphId];
        bytes32 take2Txid = BitvmTxParser.parseTake2Tx(rawTake2Tx);
        require(take2Txid == operatorData.take2Txid, "take2 txid mismatch");
        (bytes32 blockHash, bytes32 merkleRoot) = MerkleProof.parseBtcBlockHeader(take2Proof.rawHeader);
        require(bitcoinSPV.blockHash(take2Proof.height) == blockHash, "invalid header");
        require(MerkleProof.verifyMerkleProof(merkleRoot, take2Proof.proof, take2Txid, take2Proof.index), "unable to verify");

        peginData.status = PeginStatus.Claimed;
        withdrawData.status = WithdrawStatus.Complete;

        emit WithdrawUnhappyPath(instanceId, graphId, take2Txid);
    }

    function finishWithdrawDisproved(
        bytes16 graphId,
        BitvmTxParser.BitcoinTx calldata rawDisproveTx,
        MerkleProof.BitcoinTxProof calldata disproveProof,
        BitvmTxParser.BitcoinTx calldata rawChallengeTx,
        MerkleProof.BitcoinTxProof calldata challengeProof
    ) external onlyRelayerOrOperator(graphId) {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        bytes16 instanceId = withdrawData.instanceId;
        // Malicious operator may skip initWithdraw & procceedWithdraw

        // verify Disprove tx
        OperatorData storage operatorData = operatorDataMap[graphId];
        (bytes32 disproveTxid, bytes32 assertFinalTxid) = BitvmTxParser.parseDisproveTx(rawDisproveTx);
        require(assertFinalTxid == operatorData.assertFinalTxid, "Assert-Final txid mismatch");
        (bytes32 blockHash, bytes32 merkleRoot) = MerkleProof.parseBtcBlockHeader(disproveProof.rawHeader);
        require(bitcoinSPV.blockHash(disproveProof.height) == blockHash, "invalid header in disproveProof");
        require(
            MerkleProof.verifyMerkleProof(merkleRoot, disproveProof.proof, disproveTxid, disproveProof.index),
            "unable to verify disprove merkle proof"
        );
        withdrawData.status = WithdrawStatus.Disproved;

        // verify Challenge tx
        (bytes32 challengeTxid, bytes32 kickoffTxid, address challengerAddress) =
            BitvmTxParser.parseChallengeTx(rawChallengeTx);
        require(kickoffTxid == operatorData.kickoffTxid, "Kickoff txid mismatch");
        (blockHash, merkleRoot) = MerkleProof.parseBtcBlockHeader(challengeProof.rawHeader);
        require(bitcoinSPV.blockHash(challengeProof.height) == blockHash, "invalid header in challengeProof");
        require(
            MerkleProof.verifyMerkleProof(merkleRoot, challengeProof.proof, challengeTxid, challengeProof.index),
            "unable to verify challenge merkle proof"
        );

        emit WithdrawDisproved(instanceId, graphId, disproveTxid, challengeTxid, challengerAddress);
    }
}
