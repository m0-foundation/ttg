// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { BatchGovernor } from "../../src/abstract/BatchGovernor.sol";

contract BatchGovernorHarness is BatchGovernor {
    mapping(uint256 proposalId => ProposalState state) internal _states;

    constructor(string memory name_, address voteToken_) BatchGovernor(name_, voteToken_) {}

    /* ============ Interactive Functions ============ */

    function execute(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory callDatas_,
        bytes32 descriptionHash_
    ) external payable returns (uint256 proposalId_) {}

    function propose(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory callDatas_,
        string memory description_
    ) external returns (uint256 proposalId_) {}

    function setProposal(
        bytes memory callData_,
        uint256 voteStart_,
        bool executed_,
        address proposer_,
        uint256 thresholdRatio_,
        uint256 noWeight_,
        uint256 yesWeight_
    ) external returns (uint256 proposalId_) {
        proposalId_ = _hashProposal(callData_, uint16(voteStart_));

        _proposals[proposalId_] = Proposal({
            voteStart: uint16(voteStart_),
            executed: executed_,
            proposer: proposer_,
            thresholdRatio: uint16(thresholdRatio_),
            noWeight: noWeight_,
            yesWeight: yesWeight_
        });
    }

    function setState(uint256 proposalId_, ProposalState state_) external {
        _states[proposalId_] = state_;
    }

    function tryExecute(
        bytes memory callData_,
        uint16 latestVoteStart_,
        uint16 earliestVoteStart_
    ) external payable returns (uint256 proposalId_) {
        return _tryExecute(callData_, latestVoteStart_, earliestVoteStart_);
    }

    fallback() external {}

    /* ============ View/Pure Functions ============ */

    function COUNTING_MODE() external pure returns (string memory) {
        return "";
    }

    function getDigest(bytes32 internalDigest_) external view returns (bytes32) {
        return _getDigest(internalDigest_);
    }

    function quorum() external view returns (uint256) {}

    function state(uint256 proposalId_) public view override returns (ProposalState) {
        return _states[proposalId_];
    }

    /* ============ Internal Interactive Functions ============ */

    function _createProposal(uint256 proposalId_, uint16 voteStart_) internal override {}

    /* ============ Internal View/Pure Functions ============ */

    function getReasonListHash(string[] calldata reasonList_) external pure returns (bytes32) {
        return _getReasonListHash(reasonList_);
    }

    function _revertIfInvalidCalldata(bytes memory callData_) internal pure override {}

    function _votingDelay() internal view override returns (uint16) {}

    function _votingPeriod() internal view override returns (uint16) {}
}
