// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IBitcoinSPV} from "./interfaces/IBitcoinSPV.sol";
import {IPegBTC} from "./interfaces/IPegBTC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CommitteeManagement} from "./CommitteeManagement.sol";
import {StakeManagement} from "./StakeManagement.sol";
import {Converter} from "./libraries/Converter.sol";
import {BitvmTxParser} from "./libraries/BitvmTxParser.sol";
import {MerkleProof} from "./libraries/MerkleProof.sol";

// Custom errors to reduce bytecode size (replace long revert strings)
error NotCommittee();
error NotOperator();
error InstanceUsed();
error NotPending();
error WindowExpired();
error WindowNotExpired();
error NotEnoughCommittee();
error InvalidPubkeyLen();
error InvalidPubkeyParity();
error InstanceMismatch();
error PeginAmountMismatch();
error InvalidHeader();
error MerkleVerifyFail();
error InvalidSignatures();
error FeeTooHigh();
error OperatorNotRegistered();
error StakeInsufficient();
error GraphAlreadyPosted();
error GraphPeginTxidMismatch();
error WithdrawStatusInvalid();
error NotWithdrawable();
error TimelockNotExpired();
error KickoffHeightLow();
error TxidMismatch();
error AlreadyDisproved();
error IndexOutOfRange();
error UnknownDisproveType();
error DisproveInvalidHeader();

contract BitvmPolicy {
    uint64 constant rateMultiplier = 10000;

    uint64 public minChallengeAmountSats;
    uint64 public minPeginFeeSats;
    uint64 public peginFeeRate;
    uint64 public minOperatorRewardSats;
    uint64 public operatorRewardRate;

    uint64 public minStakeAmount;
    uint64 public minChallengerReward;
    uint64 public minDisproverReward;
    uint64 public minSlashAmount;

    // TODO Initializer & setters
}

contract GatewayUpgradeable is BitvmPolicy, Initializable {
    using ECDSA for bytes32;

    // EIP-712-like typehash constants to avoid recomputing literals
    bytes32 private constant POST_PEGIN_TYPEHASH =
        keccak256("POST_PEGIN_DATA(address contract,bytes16 instanceId,bytes32 peginTxid)");
    bytes32 private constant POST_GRAPH_TYPEHASH =
        keccak256("POST_GRAPH_DATA(address contract,bytes16 instanceId,bytes16 graphId,bytes32 graphDataHash)");
    bytes32 private constant CANCEL_WITHDRAW_TYPEHASH = keccak256("CANCEL_WITHDRAW(address contract,bytes16 graphId)");
    bytes32 private constant UNLOCK_STAKE_TYPEHASH =
        keccak256("UNLOCK_OPERATOR_STAKE(address contract,address operator,uint256 amount)");

    event BridgeInRequest(
        bytes16 indexed instanceId,
        address indexed depositorAddress,
        uint64 peginAmountSats,
        uint64[3] txnFees,
        Utxo[] userInputs,
        bytes32 userXonlyPubkey,
        string userChangeAddress,
        string userRefundAddress
    );
    event CommitteeResponse(bytes16 indexed instanceId, address indexed committeeAddress, bytes committeePubkey);
    event BridgeIn(
        address indexed depositorAddress,
        bytes16 indexed instanceId,
        uint64 indexed peginAmountSats,
        uint64 feeAmountSats
    );
    event InitWithdraw(
        bytes16 indexed instanceId, bytes16 indexed graphId, address indexed operatorAddress, uint64 withdrawAmountSats
    );
    event CancelWithdraw(bytes16 indexed instanceId, bytes16 indexed graphId, address indexed triggerAddress);
    event ProceedWithdraw(bytes16 indexed instanceId, bytes16 indexed graphId, bytes32 kickoffTxid);
    event WithdrawHappyPath(
        bytes16 indexed instanceId,
        bytes16 indexed graphId,
        bytes32 take1Txid,
        address indexed operatorAddress,
        uint64 rewardAmountSats
    );
    event WithdrawUnhappyPath(
        bytes16 indexed instanceId,
        bytes16 indexed graphId,
        bytes32 take2Txid,
        address indexed operatorAddress,
        uint64 rewardAmountSats
    );
    event WithdrawDisproved(
        bytes16 indexed instanceId,
        bytes16 indexed graphId,
        DisproveTxType disproveTxType,
        uint256 txnIndex,
        bytes32 challengeStartTxid,
        bytes32 challengeFinishTxid,
        address challengerAddress,
        address disproverAddress,
        uint64 challengerRewardAmount,
        uint64 disproverRewardAmount
    );

    enum DisproveTxType {
        AssertTimeout,
        OperatorCommitTimeout,
        OperatorNack,
        Disprove,
        QuickChallenge,
        ChallengeIncompeleteKickoff
    }
    enum PeginStatus {
        None,
        Pending,
        Withdrawbale,
        Processing,
        Locked,
        Claimed,
        Discarded
    }
    enum WithdrawStatus {
        None,
        Processing,
        Initialized,
        Canceled,
        Complete,
        Disproved
    }

    struct Utxo {
        bytes32 txid;
        uint32 vout;
        uint64 amountSats;
    }

    struct PeginDataInner {
        PeginStatus status;
        bytes16 instanceId;
        address depositorAddress;
        uint64 peginAmountSats;
        uint64[3] txnFees;
        Utxo[] userInputs;
        bytes32 userXonlyPubkey;
        string userChangeAddress;
        string userRefundAddress;
        bytes32 peginTxid;
        uint256 createdAt;
        // EnumerableMap
        address[] committeeAddresses;
        mapping(address value => uint256) committeeAddressPositions;
        mapping(address => bytes1) committeePubkeyParitys; // even (0x02), odd (0x03)
        mapping(address => bytes32) committeeXonlyPubkeys;
    }

    struct PeginData {
        PeginStatus status;
        bytes16 instanceId;
        address depositorAddress;
        uint64 peginAmountSats;
        uint64[3] txnFees; // [ peginPrepare , peginComfirm  peginCancel ]
        Utxo[] userInputs;
        bytes32 userXonlyPubkey;
        string userChangeAddress;
        string userRefundAddress;
        bytes32 peginTxid;
        uint256 createdAt;
        address[] committeeAddresses;
        bytes[] committeePubkeys;
    }

    struct WithdrawData {
        WithdrawStatus status;
        bytes32 peginTxid;
        address operatorAddress;
        bytes16 instanceId;
        uint256 lockAmount;
        uint256 btcBlockHeightAtWithdraw;
    }

    struct GraphData {
        bytes1 operatorPubkeyPrefix;
        bytes32 operatorPubkey;
        bytes32 peginTxid;
        bytes32 kickoffTxid;
        bytes32 take1Txid;
        bytes32 take2Txid;
        bytes32 commitTimoutTxid;
        bytes32[] assertTimoutTxids;
        bytes32[] NackTxids;
    }

    IPegBTC public pegBTC;
    IBitcoinSPV public bitcoinSPV;
    CommitteeManagement public committeeManagement;
    StakeManagement public stakeManagement;

    uint256 public responseWindowBlocks = 200; // 200 goat blocks ~ 10 minutes

    uint256 public cancelWithdrawTimelock = 144; // 144 btc blocks ~ 24 hours

    bytes16[] public instanceIds;
    mapping(bytes16 instanceId => bytes16[] graphIds) public instanceIdToGraphIds;
    mapping(bytes16 instanceId => PeginDataInner) public peginDataMap;
    mapping(bytes16 graphId => GraphData) public graphDataMap;
    mapping(bytes16 graphId => WithdrawData) public withdrawDataMap;

    // initializer
    function initialize(
        IPegBTC _pegBTC,
        IBitcoinSPV _bitcoinSPV,
        CommitteeManagement _committeeManagement,
        StakeManagement _stakeManagement
    ) external initializer {
        // set initial parameters
        minChallengeAmountSats = 1000000; // 0.01 BTC
        minPeginFeeSats = 5000; // 0.00005 BTC
        peginFeeRate = 50; // 0.5%
        minOperatorRewardSats = 3000; // 0.00003 BTC
        operatorRewardRate = 30; // 0.3%
        minStakeAmount = 6000000; // 0.06 BTC
        minChallengerReward = 1250000; // 0.0125 BTC
        minDisproverReward = 250000; // 0.0025 BTC
        minSlashAmount = 3000000; // 0.03 BTC
        responseWindowBlocks = 200; // 200 goat blocks ~ 10 minutes
        cancelWithdrawTimelock = 144; // 144 btc blocks ~ 24 hours

        pegBTC = _pegBTC;
        bitcoinSPV = _bitcoinSPV;
        committeeManagement = _committeeManagement;
        stakeManagement = _stakeManagement;
    }

    // getters
    function getGraphIdsByInstanceId(bytes16 instanceId) external view returns (bytes16[] memory) {
        return instanceIdToGraphIds[instanceId];
    }

    function getPeginData(bytes16 instanceId) external view returns (PeginData memory) {
        PeginDataInner storage data = peginDataMap[instanceId];
        return PeginData({
            status: data.status,
            instanceId: data.instanceId,
            depositorAddress: data.depositorAddress,
            peginAmountSats: data.peginAmountSats,
            txnFees: data.txnFees,
            userInputs: data.userInputs,
            userXonlyPubkey: data.userXonlyPubkey,
            userChangeAddress: data.userChangeAddress,
            userRefundAddress: data.userRefundAddress,
            peginTxid: data.peginTxid,
            createdAt: data.createdAt,
            committeeAddresses: data.committeeAddresses,
            committeePubkeys: getCommitteePubkeysUnsafe(instanceId)
        });
    }

    function getGraphData(bytes16 graphId) external view returns (GraphData memory) {
        return graphDataMap[graphId];
    }
    // helpers

    function verifyCommitteeSignatures(bytes32 msgHash, bytes[] memory signatures, address[] memory members)
        public
        pure
        returns (bool)
    {
        address[] memory signers = new address[](signatures.length);
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = msgHash.recover(signatures[i]);
            signers[i] = signer;
        }
        // require signers contains all members
        for (uint256 i = 0; i < members.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < signers.length; j++) {
                if (members[i] == signers[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return false;
            }
        }
        return true;
    }

    function getPostPeginDigest(bytes16 instanceId, bytes32 peginTxid) public view returns (bytes32) {
        return keccak256(abi.encode(POST_PEGIN_TYPEHASH, address(this), instanceId, peginTxid));
    }

    function getPostGraphDigest(bytes16 instanceId, bytes16 graphId, GraphData calldata graphData)
        public
        view
        returns (bytes32)
    {
        bytes32 graphDataHash = keccak256(abi.encode(graphData));
        return keccak256(abi.encode(POST_GRAPH_TYPEHASH, address(this), instanceId, graphId, graphDataHash));
    }

    function getCancelWithdrawDigest(bytes16 graphId) internal view returns (bytes32) {
        return keccak256(abi.encode(CANCEL_WITHDRAW_TYPEHASH, address(this), graphId));
    }

    function getCancelWithdrawDigestNonced(bytes16 graphId, uint256 nonce) public view returns (bytes32) {
        bytes32 msgHash = getCancelWithdrawDigest(graphId);
        return committeeManagement.getNoncedDigest(msgHash, nonce);
    }

    function getUnlockStakeDigest(address operator, uint256 amount) internal view returns (bytes32) {
        return keccak256(abi.encode(UNLOCK_STAKE_TYPEHASH, address(this), operator, amount));
    }

    function getUnlockStakeDigestNonced(address operator, uint256 amount, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        bytes32 msgHash = getUnlockStakeDigest(operator, amount);
        return committeeManagement.getNoncedDigest(msgHash, nonce);
    }

    modifier onlyCommittee() {
        if (!committeeManagement.isCommitteeMember(msg.sender)) revert NotCommittee();
        _;
    }

    modifier onlyOperator(bytes16 graphId) {
        if (withdrawDataMap[graphId].operatorAddress != msg.sender) revert NotOperator();
        _;
    }

    function postPeginRequest(
        bytes16 instanceId,
        uint64 peginAmountSats,
        uint64[3] calldata txnFees,
        address receiverAddress,
        Utxo[] calldata userInputs,
        bytes32 userXonlyPubkey,
        string calldata userChangeAddress,
        string calldata userRefundAddress
    ) external payable {
        PeginDataInner storage peginData = peginDataMap[instanceId];
        if (peginData.status != PeginStatus.None) revert InstanceUsed();
        // TODO: check peginAmount,feeRate,userInputs
        // TODO: charge fee

        peginData.status = PeginStatus.Pending;
        peginData.instanceId = instanceId;
        peginData.depositorAddress = receiverAddress;
        peginData.peginAmountSats = peginAmountSats;
        peginData.txnFees = txnFees;
        peginData.userInputs = userInputs;
        peginData.userXonlyPubkey = userXonlyPubkey;
        peginData.userChangeAddress = userChangeAddress;
        peginData.userRefundAddress = userRefundAddress;
        peginData.createdAt = block.number;
        instanceIds.push(instanceId);

        emit BridgeInRequest(
            instanceId,
            receiverAddress,
            peginAmountSats,
            txnFees,
            userInputs,
            userXonlyPubkey,
            userChangeAddress,
            userRefundAddress
        );
    }

    function answerPeginRequest(bytes16 instanceId, bytes memory committeePubkey) external onlyCommittee {
        PeginDataInner storage peginData = peginDataMap[instanceId];
        if (peginData.status != PeginStatus.Pending) revert NotPending();
        if (peginData.createdAt + responseWindowBlocks < block.number) revert WindowExpired();
        if (committeePubkey.length != 33) revert InvalidPubkeyLen();
        bytes1 committeePubkeyParity = committeePubkey[0];
        if (!(committeePubkeyParity == 0x02 || committeePubkeyParity == 0x03)) revert InvalidPubkeyParity();
        bytes32 committeeXonlyPubkey;
        assembly {
            committeeXonlyPubkey := mload(add(committeePubkey, 0x21))
        }

        address committeeAddress = msg.sender;
        if (peginData.committeeAddressPositions[committeeAddress] == 0) {
            peginData.committeeAddresses.push(committeeAddress);
            // The value is stored at length-1, but we add 1 to all indexes and use 0 as a sentinel value
            peginData.committeeAddressPositions[committeeAddress] = peginData.committeeAddresses.length;
        }
        peginData.committeePubkeyParitys[committeeAddress] = committeePubkeyParity;
        peginData.committeeXonlyPubkeys[committeeAddress] = committeeXonlyPubkey;

        emit CommitteeResponse(instanceId, committeeAddress, committeePubkey);
    }

    function getCommitteePubkeys(bytes16 instanceId) public view returns (bytes[] memory committeePubkeys) {
        if (peginDataMap[instanceId].createdAt + responseWindowBlocks >= block.number) revert WindowNotExpired();
        committeePubkeys = getCommitteePubkeysUnsafe(instanceId);
        if (committeePubkeys.length < committeeManagement.quorumSize()) revert NotEnoughCommittee();
    }

    function getCommitteeAddresses(bytes16 instanceId) public view returns (address[] memory committeeAddresses) {
        if (peginDataMap[instanceId].createdAt + responseWindowBlocks >= block.number) revert WindowNotExpired();
        committeeAddresses = peginDataMap[instanceId].committeeAddresses;
        if (committeeAddresses.length < committeeManagement.quorumSize()) revert NotEnoughCommittee();
    }

    function getCommitteePubkeysUnsafe(bytes16 instanceId) public view returns (bytes[] memory committeePubkeys) {
        PeginDataInner storage peginData = peginDataMap[instanceId];
        committeePubkeys = new bytes[](peginData.committeeAddresses.length);
        for (uint256 i = 0; i < peginData.committeeAddresses.length; ++i) {
            address committeeAddress = peginData.committeeAddresses[i];
            bytes1 parity = peginData.committeePubkeyParitys[committeeAddress];
            bytes32 XonlyPubkeys = peginData.committeeXonlyPubkeys[committeeAddress];
            committeePubkeys[i] = abi.encodePacked(parity, XonlyPubkeys);
        }
    }

    // TODO: post canceled pegin request?

    function postPeginData(
        bytes16 instanceId,
        BitvmTxParser.BitcoinTx calldata rawPeginTx,
        MerkleProof.BitcoinTxProof calldata peginProof,
        bytes[] calldata committeeSigs
    ) external onlyCommittee {
        PeginDataInner storage peginData = peginDataMap[instanceId];
        if (peginData.status != PeginStatus.Pending) revert NotPending();
        (bytes32 peginTxid, uint64 peginAmountSats, address depositorAddress, bytes16 parsedInstanceId) =
            BitvmTxParser.parsePegin(rawPeginTx);
        if (parsedInstanceId != instanceId) revert InstanceMismatch();
        if (peginAmountSats != peginData.peginAmountSats) revert PeginAmountMismatch();

        // validate pegin tx
        (bytes32 blockHash, bytes32 merkleRoot) = MerkleProof.parseBtcBlockHeader(peginProof.rawHeader);
        if (bitcoinSPV.blockHash(peginProof.height) != blockHash) revert InvalidHeader();
        if (!MerkleProof.verifyMerkleProof(merkleRoot, peginProof.proof, peginTxid, peginProof.index)) {
            revert MerkleVerifyFail();
        }

        // validate committeeSigs
        bytes32 pegin_digest = getPostPeginDigest(instanceId, peginTxid);
        if (!verifyCommitteeSignatures(pegin_digest, committeeSigs, getCommitteeAddresses(instanceId))) {
            revert InvalidSignatures();
        }

        // update storage
        peginData.status = PeginStatus.Withdrawbale;
        peginData.peginTxid = peginTxid;

        // mint pegBTC to user
        // deduct a fee from the User to cover the Operator's peg-out reward
        uint64 feeAmountSats = minPeginFeeSats + peginAmountSats * peginFeeRate / rateMultiplier;
        if (feeAmountSats >= peginAmountSats) revert FeeTooHigh();
        pegBTC.mint(depositorAddress, Converter.amountFromSats(peginAmountSats - feeAmountSats));
        pegBTC.mint(address(this), Converter.amountFromSats(feeAmountSats));

        emit BridgeIn(depositorAddress, instanceId, peginAmountSats, feeAmountSats);
    }

    function postGraphData(
        bytes16 instanceId,
        bytes16 graphId,
        GraphData calldata graphData,
        bytes[] calldata committeeSigs
    ) public onlyCommittee {
        // check operator stake
        // Note:committee should check operator's locked stake before pre-signed any graph txns
        address operatorStakeAddress = stakeManagement.pubkeyToAddress(graphData.operatorPubkey);
        if (operatorStakeAddress == address(0)) revert OperatorNotRegistered();
        if (stakeManagement.lockedStakeOf(operatorStakeAddress) < minStakeAmount) revert StakeInsufficient();

        // check committeeSigs
        bytes32 graph_digest = getPostGraphDigest(instanceId, graphId, graphData);
        if (!verifyCommitteeSignatures(graph_digest, committeeSigs, getCommitteeAddresses(instanceId))) {
            revert InvalidSignatures();
        }

        // check graph data
        if (graphDataMap[graphId].peginTxid != 0) revert GraphAlreadyPosted();
        PeginDataInner storage peginData = peginDataMap[instanceId];
        if (graphData.peginTxid != peginData.peginTxid) revert GraphPeginTxidMismatch();

        // store graph data
        graphDataMap[graphId] = graphData;
        instanceIdToGraphIds[instanceId].push(graphId);
    }

    function initWithdraw(bytes16 instanceId, bytes16 graphId) external {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        if (!(withdrawData.status == WithdrawStatus.None || withdrawData.status == WithdrawStatus.Canceled)) {
            revert WithdrawStatusInvalid();
        }
        PeginDataInner storage peginData = peginDataMap[instanceId];
        if (peginData.status != PeginStatus.Withdrawbale) revert NotWithdrawable();

        // lock the pegin utxo so others can not withdraw it
        peginData.status = PeginStatus.Locked;

        // lock operator's pegBTC
        uint256 lockAmount = Converter.amountFromSats(peginData.peginAmountSats);
        pegBTC.transferFrom(msg.sender, address(this), lockAmount);

        withdrawData.peginTxid = peginData.peginTxid;
        withdrawData.operatorAddress = msg.sender;
        withdrawData.status = WithdrawStatus.Initialized;
        withdrawData.instanceId = instanceId;
        withdrawData.lockAmount = lockAmount;
        withdrawData.btcBlockHeightAtWithdraw = bitcoinSPV.latestConfirmedHeight();

        emit InitWithdraw(instanceId, graphId, withdrawData.operatorAddress, peginData.peginAmountSats);
    }

    function cancelWithdraw(bytes16 graphId) external onlyOperator(graphId) {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        PeginDataInner storage peginData = peginDataMap[withdrawData.instanceId];
        if (withdrawData.status != WithdrawStatus.Initialized) revert WithdrawStatusInvalid();
        if (withdrawData.btcBlockHeightAtWithdraw + cancelWithdrawTimelock >= bitcoinSPV.latestConfirmedHeight()) {
            revert TimelockNotExpired();
        }
        withdrawData.status = WithdrawStatus.Canceled;
        pegBTC.transfer(msg.sender, withdrawData.lockAmount);
        peginData.status = PeginStatus.Withdrawbale;

        emit CancelWithdraw(withdrawData.instanceId, graphId, msg.sender);
    }

    function committeeCancelWithdraw(bytes16 graphId, uint256 nonce, bytes[] calldata committeeSigs) external {
        // validate committeeSigs
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        bytes32 cancel_digest = getCancelWithdrawDigest(graphId);
        committeeManagement.executeNoncedSignatures(cancel_digest, nonce, committeeSigs);
        // update storage
        PeginDataInner storage peginData = peginDataMap[withdrawData.instanceId];
        if (withdrawData.status != WithdrawStatus.Initialized) revert WithdrawStatusInvalid();
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
    ) external onlyCommittee {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        bytes16 instanceId = withdrawData.instanceId;
        if (withdrawData.status != WithdrawStatus.Initialized) revert WithdrawStatusInvalid();
        if (withdrawData.btcBlockHeightAtWithdraw >= kickoffProof.height) revert KickoffHeightLow();

        GraphData storage graphData = graphDataMap[graphId];
        bytes32 kickoffTxid = BitvmTxParser.computeTxid(rawKickoffTx);
        if (kickoffTxid != graphData.kickoffTxid) revert TxidMismatch();
        (bytes32 blockHash, bytes32 merkleRoot) = MerkleProof.parseBtcBlockHeader(kickoffProof.rawHeader);
        if (bitcoinSPV.blockHash(kickoffProof.height) != blockHash) revert InvalidHeader();
        if (!MerkleProof.verifyMerkleProof(merkleRoot, kickoffProof.proof, kickoffTxid, kickoffProof.index)) {
            revert MerkleVerifyFail();
        }

        // once kickoff is braodcasted , operator will not be able to cancel withdrawal
        withdrawData.status = WithdrawStatus.Processing;

        // burn pegBTC
        pegBTC.burn(withdrawData.lockAmount);

        emit ProceedWithdraw(instanceId, graphId, kickoffTxid);
    }

    function finishWithdrawHappyPath(
        bytes16 graphId,
        BitvmTxParser.BitcoinTx calldata rawTake1Tx,
        MerkleProof.BitcoinTxProof calldata take1Proof
    ) external onlyCommittee {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        bytes16 instanceId = withdrawData.instanceId;
        PeginDataInner storage peginData = peginDataMap[instanceId];
        if (withdrawData.status != WithdrawStatus.Processing) revert WithdrawStatusInvalid();

        GraphData storage graphData = graphDataMap[graphId];
        bytes32 take1Txid = BitvmTxParser.computeTxid(rawTake1Tx);
        if (take1Txid != graphData.take1Txid) revert TxidMismatch();
        (bytes32 blockHash, bytes32 merkleRoot) = MerkleProof.parseBtcBlockHeader(take1Proof.rawHeader);
        if (bitcoinSPV.blockHash(take1Proof.height) != blockHash) revert InvalidHeader();
        if (!MerkleProof.verifyMerkleProof(merkleRoot, take1Proof.proof, take1Txid, take1Proof.index)) {
            revert MerkleVerifyFail();
        }

        peginData.status = PeginStatus.Claimed;
        withdrawData.status = WithdrawStatus.Complete;

        // incentive mechanism for honest Operators
        uint64 rewardAmountSats =
            minOperatorRewardSats + peginData.peginAmountSats * operatorRewardRate / rateMultiplier;
        pegBTC.transfer(withdrawData.operatorAddress, Converter.amountFromSats(rewardAmountSats));

        emit WithdrawHappyPath(instanceId, graphId, take1Txid, withdrawData.operatorAddress, rewardAmountSats);
    }

    function finishWithdrawUnhappyPath(
        bytes16 graphId,
        BitvmTxParser.BitcoinTx calldata rawTake2Tx,
        MerkleProof.BitcoinTxProof calldata take2Proof
    ) external onlyCommittee {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        bytes16 instanceId = withdrawData.instanceId;
        PeginDataInner storage peginData = peginDataMap[instanceId];
        if (withdrawData.status != WithdrawStatus.Processing) revert WithdrawStatusInvalid();

        GraphData storage graphData = graphDataMap[graphId];
        bytes32 take2Txid = BitvmTxParser.computeTxid(rawTake2Tx);
        if (take2Txid != graphData.take2Txid) revert TxidMismatch();
        (bytes32 blockHash, bytes32 merkleRoot) = MerkleProof.parseBtcBlockHeader(take2Proof.rawHeader);
        if (bitcoinSPV.blockHash(take2Proof.height) != blockHash) revert InvalidHeader();
        if (!MerkleProof.verifyMerkleProof(merkleRoot, take2Proof.proof, take2Txid, take2Proof.index)) {
            revert MerkleVerifyFail();
        }

        peginData.status = PeginStatus.Claimed;
        withdrawData.status = WithdrawStatus.Complete;

        // incentive mechanism for honest Operators
        uint64 rewardAmountSats =
            minOperatorRewardSats + peginData.peginAmountSats * operatorRewardRate / rateMultiplier;
        pegBTC.transfer(withdrawData.operatorAddress, Converter.amountFromSats(rewardAmountSats));

        emit WithdrawUnhappyPath(instanceId, graphId, take2Txid, withdrawData.operatorAddress, rewardAmountSats);
    }

    // if no challengeStartTx happens (for QuickChallenge & ChallengeIncompeleteKickoff), set rawChallengeStartTx.inputVector to empty
    function finishWithdrawDisproved(
        bytes16 graphId,
        DisproveTxType disproveTxType,
        uint256 txnIndex, // nack txns index or assert timeout txns index, ignored for other disprove types
        BitvmTxParser.BitcoinTx calldata rawChallengeStartTx,
        MerkleProof.BitcoinTxProof calldata challengeStartTxProof,
        BitvmTxParser.BitcoinTx calldata rawChallengeFinishTx,
        MerkleProof.BitcoinTxProof calldata challengeFinishTxProof
    ) external onlyCommittee {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        GraphData storage graphData = graphDataMap[graphId];
        bytes16 instanceId = withdrawData.instanceId;
        // Malicious operator may skip initWithdraw & procceedWithdraw
        if (withdrawData.status == WithdrawStatus.Disproved) revert AlreadyDisproved();

        // verify ChallengeStart tx
        bytes32 challengeStartTxid;
        address challengerAddress;
        bytes32 kickoffTxid;
        uint32 kickoffVout;
        bytes32 blockHash;
        bytes32 merkleRoot;
        if (
            (
                disproveTxType == DisproveTxType.QuickChallenge
                    || disproveTxType == DisproveTxType.ChallengeIncompeleteKickoff
            ) && (rawChallengeStartTx.inputVector.length == 0)
        ) {
            // no challenge start tx
        } else {
            (challengeStartTxid, kickoffTxid, kickoffVout, challengerAddress) =
                BitvmTxParser.parseChallengeTx(rawChallengeStartTx);
            if (kickoffTxid != graphData.kickoffTxid) revert TxidMismatch();
            if (kickoffVout != BitvmTxParser.CHALLENGE_CONNECTOR_VOUT) revert TxidMismatch();
            (blockHash, merkleRoot) = MerkleProof.parseBtcBlockHeader(challengeStartTxProof.rawHeader);
            if (bitcoinSPV.blockHash(challengeStartTxProof.height) != blockHash) revert DisproveInvalidHeader();
            if (
                !MerkleProof.verifyMerkleProof(
                    merkleRoot, challengeStartTxProof.proof, challengeStartTxid, challengeStartTxProof.index
                )
            ) revert MerkleVerifyFail();
        }

        // verify ChallengeFinish tx
        bytes32 challengeFinishTxid;
        address disproverAddress;
        if (disproveTxType == DisproveTxType.AssertTimeout) {
            (challengeFinishTxid) = BitvmTxParser.computeTxid(rawChallengeFinishTx);
            if (graphData.assertTimoutTxids.length <= txnIndex) revert IndexOutOfRange();
            if (challengeFinishTxid != graphData.assertTimoutTxids[txnIndex]) revert TxidMismatch();
        } else if (disproveTxType == DisproveTxType.OperatorCommitTimeout) {
            (challengeFinishTxid) = BitvmTxParser.computeTxid(rawChallengeFinishTx);
            if (challengeFinishTxid != graphData.commitTimoutTxid) revert TxidMismatch();
        } else if (disproveTxType == DisproveTxType.OperatorNack) {
            (challengeFinishTxid) = BitvmTxParser.computeTxid(rawChallengeFinishTx);
            if (graphData.NackTxids.length <= txnIndex) revert IndexOutOfRange();
            if (challengeFinishTxid != graphData.NackTxids[txnIndex]) revert TxidMismatch();
        } else if (disproveTxType == DisproveTxType.Disprove) {
            (challengeFinishTxid, kickoffTxid, kickoffVout, disproverAddress) =
                BitvmTxParser.parseDisproveTx(rawChallengeFinishTx);
            if (kickoffTxid != graphData.kickoffTxid) revert TxidMismatch();
            if (kickoffVout != BitvmTxParser.DISPROVE_CONNECTOR_VOUT) revert TxidMismatch();
        } else if (disproveTxType == DisproveTxType.QuickChallenge) {
            (challengeFinishTxid, kickoffTxid, kickoffVout, disproverAddress) =
                BitvmTxParser.parseQuickChallengeTx(rawChallengeFinishTx);
            if (kickoffTxid != graphData.kickoffTxid) revert TxidMismatch();
            if (kickoffVout != BitvmTxParser.GUARDIAN_CONNECTOR_VOUT) revert TxidMismatch();
        } else if (disproveTxType == DisproveTxType.ChallengeIncompeleteKickoff) {
            (challengeFinishTxid, kickoffTxid, kickoffVout, disproverAddress) =
                BitvmTxParser.parseChallengeIncompleteKickoffTx(rawChallengeFinishTx);
            if (kickoffTxid != graphData.kickoffTxid) revert TxidMismatch();
            if (kickoffVout != BitvmTxParser.GUARDIAN_CONNECTOR_VOUT) revert TxidMismatch();
        } else {
            revert UnknownDisproveType();
        }
        (blockHash, merkleRoot) = MerkleProof.parseBtcBlockHeader(challengeFinishTxProof.rawHeader);
        if (bitcoinSPV.blockHash(challengeFinishTxProof.height) != blockHash) revert DisproveInvalidHeader();
        if (
            !MerkleProof.verifyMerkleProof(
                merkleRoot, challengeFinishTxProof.proof, challengeFinishTxid, challengeFinishTxProof.index
            )
        ) revert MerkleVerifyFail();
        withdrawData.status = WithdrawStatus.Disproved;

        // slash Operator & reward Challenger and Disprover
        IERC20 stakeToken = IERC20(stakeManagement.stakeTokenAddress());
        address operatorStakeAddress = stakeManagement.pubkeyToAddress(graphData.operatorPubkey);
        uint256 slashAmount = minSlashAmount;
        uint256 operatorStake = stakeManagement.stakeOf(operatorStakeAddress);
        if (operatorStake < slashAmount) slashAmount = operatorStake;
        stakeManagement.slashStake(operatorStakeAddress, slashAmount);

        uint64 challengerRewardAmount = minChallengerReward;
        uint64 disproverRewardAmount = minDisproverReward;
        if (challengerAddress != address(0)) {
            stakeToken.transfer(challengerAddress, challengerRewardAmount);
        }
        if (disproverAddress != address(0)) {
            stakeToken.transfer(disproverAddress, disproverRewardAmount);
        }

        emit WithdrawDisproved(
            instanceId,
            graphId,
            disproveTxType,
            txnIndex,
            challengeStartTxid,
            challengeFinishTxid,
            challengerAddress,
            disproverAddress,
            challengerRewardAmount,
            disproverRewardAmount
        );
    }

    /*
        If an operator wants to unlockStake, they must prove to the committee 
        that they have processed or discarded all graphs (for example, by spending the 
        prekickoff-connector through another path). Once the committee members have verified 
        this, they provide their signatures.
    */
    function unlockOperatorStake(address operator, uint256 amount, uint256 nonce, bytes[] calldata committeeSigs)
        external
    {
        bytes32 msgHash = getUnlockStakeDigest(operator, amount);
        committeeManagement.executeNoncedSignatures(msgHash, nonce, committeeSigs);
        stakeManagement.unlockStake(operator, amount);
    }
}
