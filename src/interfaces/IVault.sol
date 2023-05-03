// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";

interface IVault {
    event EpochRewardsDeposit(uint256 indexed epoch, address indexed token, uint256 amount);
    event TokenRewardsWithdrawn(address indexed account, address indexed token, uint256 amount);
    event VoteTokenAuction(address indexed token, uint256 indexed epoch, address indexed auction, uint256 amount);
    event VoteGovernorUpdated(address indexed newVoteGovernor, address indexed newVotingToken);

    // SPOG-triggered functions
    function depositEpochRewardTokens(uint256 epoch, address token, uint256 amount) external;
    function sellUnclaimedVoteTokens(uint256 epoch, address paymentToken, uint256 duration) external;
    function updateVoteGovernor(ISPOGGovernor newVoteGovernor) external;

    // Functions for claiming governance rewards by vote holders
    function claimVoteTokenRewards() external;
    function claimValueTokenRewards() external;
    function unclaimedVoteTokensForEpoch(uint256 epoch) external view returns (uint256);

    // Functions for withdrawing assets by value holders
    function withdrawRewardsForValueHolders(uint256 epoch, address token) external;
    function withdrawRewardsForValueHolders(uint256[] memory epochs, address token) external;
}
