// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {IBaseVault} from "src/interfaces/vaults/IBaseVault.sol";

interface IVoteVault is IBaseVault {
    event VoteTokenAuction(address indexed token, uint256 indexed epoch, address indexed auction, uint256 amount);
    event VoteGovernorUpdated(address indexed newVoteGovernor, address indexed newVotingToken);

    error NotVotedOnAllProposals();

    // Auction-related functions
    function auctionableVoteRewards(uint256 epoch) external view returns (uint256);
    function sellUnclaimedVoteTokens(uint256 epoch, address paymentToken, uint256 duration) external;

    // RESET-related functions
    function updateGovernor(ISPOGGovernor newGovernor) external;

    // Functions for claiming governance rewards by vote holders
    function claimVoteRewards(uint256 epoch) external;
    function claimValueRewards(uint256 epoch) external;
}
