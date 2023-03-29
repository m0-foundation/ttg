// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {IGovSPOG} from "src/interfaces/IGovSPOG.sol";
import {ISPOGVotes} from "src/interfaces/ISPOGVotes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

abstract contract SPOGStorage is ISPOG {
    struct SPOGData {
        uint256 tax;
        uint256 inflatorTime;
        uint256 sellTime;
        uint256 inflator;
        uint256 reward;
        uint256[2] taxRange;
        IERC20 cash;
    }

    SPOGData public spogData;

    IGovSPOG public immutable govSPOGVote;
    IGovSPOG public immutable govSPOGValue;

    // TODO: variable packing for SPOGData: https://dev.to/javier123454321/solidity-gas-optimizations-pt-3-packing-structs-23f4

    struct DoubleQuorum {
        uint256 voteValueQuorumDeadline;
        bool passedVoteQuorum;
    }

    mapping(bytes32 => DoubleQuorum) public doubleQuorumChecker;

    constructor(
        IGovSPOG _govSPOGVote,
        IGovSPOG _govSPOGValue,
        uint256 _voteTime,
        uint256 _forkTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum
    ) {
        govSPOGVote = _govSPOGVote;
        govSPOGValue = _govSPOGValue;

        // Set in GovSPOGVote
        govSPOGVote.initSPOGAddress(address(this));
        ISPOGVotes(address(govSPOGVote.votingToken())).initSPOGAddress(address(this));

        // set quorum and voting period for govSPOGVote
        govSPOGVote.updateQuorumNumerator(_voteQuorum);
        govSPOGVote.updateVotingTime(_voteTime);

        // Set in GovSPOGValue
        govSPOGValue.initSPOGAddress(address(this));
        ISPOGVotes(address(govSPOGValue.votingToken())).initSPOGAddress(address(this));

        // set quorum and voting period for govSPOGValue
        govSPOGValue.updateQuorumNumerator(_valueQuorum);
        govSPOGValue.updateVotingTime(_forkTime);
    }

    modifier onlyGovSPOGVote() {
        require(msg.sender == address(govSPOGVote), "SPOG: Only GovSPOGVote");

        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == address(govSPOGVote) || msg.sender == address(govSPOGValue), "SPOG: Only GovSPOG");

        _;
    }

    /// @dev Getter for taxRange. It returns the minimum and maximum value of `tax`
    /// @return The minimum and maximum value of `tax`
    function taxRange() external view returns (uint256, uint256) {
        return (spogData.taxRange[0], spogData.taxRange[1]);
    }

    function changeTax(uint256 _tax) external onlyGovSPOGVote {
        require(_tax >= spogData.taxRange[0] && _tax <= spogData.taxRange[1], "SPOG: Tax out of range");

        spogData.tax = _tax;

        emit TaxChanged(_tax);
    }

    /// @dev file double quorum function to change the following values: cash, taxRange, inflator, reward, voteTime, inflatorTime, sellTime, forkTime, voteQuorum, and valueQuorum.
    /// @param what The value to be changed
    /// @param value The new value
    function change(bytes32 what, bytes calldata value) external onlyGovernance {
        bytes32 identifier = keccak256(abi.encodePacked(what, value));
        if (msg.sender == address(govSPOGVote)) {
            require(!doubleQuorumChecker[identifier].passedVoteQuorum, "SPOG: Double quorum already initiated");

            doubleQuorumChecker[identifier].passedVoteQuorum = true;

            // set the deadline for the value quorum to be reached
            // 2x govSPOGValue voting period (votingDelay + votingPeriod).
            uint256 voteValueQuorumDeadline = block.number + (govSPOGValue.votingPeriod() * 2);
            doubleQuorumChecker[identifier].voteValueQuorumDeadline = voteValueQuorumDeadline;

            emit DoubleQuorumInitiated(identifier);
        } else {
            require(doubleQuorumChecker[identifier].passedVoteQuorum, "SPOG: Double quorum not met");

            require(
                doubleQuorumChecker[identifier].voteValueQuorumDeadline >= block.number,
                "SPOG: Double quorum deadline passed"
            );

            _fileWithDoubleQuorum(what, value);

            doubleQuorumChecker[identifier].passedVoteQuorum = false;

            emit DoubleQuorumFinalized(identifier);
        }
    }

    /**
     * Private Function ***
     */

    function _fileWithDoubleQuorum(bytes32 what, bytes calldata value) private {
        if (what == "cash") {
            spogData.cash = abi.decode(value, (IERC20));
        } else if (what == "taxRange") {
            spogData.taxRange = abi.decode(value, (uint256[2]));
        } else if (what == "inflator") {
            spogData.inflator = abi.decode(value, (uint256));
        } else if (what == "reward") {
            spogData.reward = abi.decode(value, (uint256));
        } else if (what == "voteTime") {
            uint256 decodedVoteTime = abi.decode(value, (uint256));
            govSPOGVote.updateVotingTime(decodedVoteTime);
        } else if (what == "inflatorTime") {
            spogData.inflatorTime = abi.decode(value, (uint256));
        } else if (what == "sellTime") {
            spogData.sellTime = abi.decode(value, (uint256));
        } else if (what == "forkTime") {
            uint256 decodedForkTime = abi.decode(value, (uint256));
            govSPOGValue.updateVotingTime(decodedForkTime);
        } else if (what == "voteQuorum") {
            uint256 decodedvoteQuorum = abi.decode(value, (uint256));
            govSPOGVote.updateQuorumNumerator(decodedvoteQuorum);
        } else if (what == "valueQuorum") {
            uint256 valueQuorum = abi.decode(value, (uint256));
            govSPOGValue.updateQuorumNumerator(valueQuorum);
        } else {
            revert InvalidParameter(what);
        }
    }
}
