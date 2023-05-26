// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "src/interfaces/vaults/IValueVault.sol";

interface IVoteVault is IValueVault {
    event VoteTokenAuction(address indexed token, uint256 indexed epoch, address indexed auction, uint256 amount);

    error NotVotedOnAllProposals();
    error NoTokensToSell();

    // Auction-related functions
    function sellInactiveVoteInflation(uint256 epoch) external;
}
