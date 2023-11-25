// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IBatchGovernor } from "../abstract/interfaces/IBatchGovernor.sol";

interface IStandardGovernor is IBatchGovernor {
    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event CashTokenSet(address indexed cashToken);

    event ProposalFeeSet(uint256 proposalFee);

    event ProposalFeeSentToVault(uint256 indexed proposalId, address indexed cashToken, uint256 proposalFee);

    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error EpochHasNoProposals();

    error FeeNotDestinedForVault(ProposalState state);

    error InvalidCashTokenAddress();

    error InvalidEmergencyGovernorAddress();

    error InvalidVaultAddress();

    error InvalidZeroGovernorAddress();

    error InvalidZeroTokenAddress();

    error NotSelfOrEmergencyGovernor();

    error NotZeroGovernor();

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function sendProposalFeeToVault(uint256 proposalId) external;

    function setCashToken(address newCashToken, uint256 newProposalFee_) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function cashToken() external view returns (address cashToken);

    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            uint16 voteStart,
            uint16 voteEnd,
            bool executed,
            ProposalState state,
            uint256 noVotes,
            uint256 yesVotes,
            address proposer
        );

    function hasVotedOnAllProposals(address voter, uint256 epoch) external view returns (bool hasVoted);

    function maxTotalZeroRewardPerActiveEpoch() external view returns (uint256 reward);

    function numberOfProposalsAt(uint256 epoch) external view returns (uint256 count);

    function numberOfProposalsVotedOnAt(uint256 epoch, address voter) external view returns (uint256 count);

    function vault() external view returns (address vault);

    function zeroToken() external view returns (address zeroToken);

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function addToList(bytes32 list, address account) external;

    function addAndRemoveFromList(bytes32 list, address accountToAdd, address accountToRemove) external;

    function removeFromList(bytes32 list, address account) external;

    function setProposalFee(uint256 newProposalFee) external;

    function updateConfig(bytes32 key, bytes32 value_) external;
}
