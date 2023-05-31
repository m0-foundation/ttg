// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

interface IVoteVault {
    // TODO: `indexed` array of epochs, does it work?
    event VoteTokenAuction(address indexed token, uint256[] indexed epochs, address indexed auction, uint256 amount);

    error NotVotedOnAllProposals();
    error NoTokensToSell();
    error AuctionAlreadyExists(uint256 epoch, address auction);

    function sellInactiveVoteInflation(uint256[] calldata epochs) external returns (address, uint256);
}
