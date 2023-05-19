// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {SPOGGovernorBase} from "src/core/governance/SPOGGovernorBase.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";

interface IVoteVault is IValueVault {
    event VoteTokenAuction(address indexed token, uint256 indexed epoch, address indexed auction, uint256 amount);
    event VoteGovernorUpdated(address indexed newVoteGovernor, address indexed newVotingToken);

    error NotVotedOnAllProposals();
    error NoTokensToSell();

    // Auction-related functions
    function sellInactiveVoteInflation(uint256 epoch, address paymentToken, uint256 duration) external;

    // RESET-related functions
    function updateGovernor(SPOGGovernorBase newGovernor) external;
}
