// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {IBaseVault} from "src/interfaces/vaults/IBaseVault.sol";

interface IVoteVault is IBaseVault {
    event VoteTokenAuction(uint256[] indexed epochs, address indexed auction, uint256 amount);
    event VoteGovernorUpdated(address indexed newVoteGovernor, address indexed newVotingToken);

    // SPOG-triggered functions
    function sellUnclaimedVoteTokens(uint256[] calldata epochs, address paymentToken, uint256 duration) external;
    function updateGovernor(ISPOGGovernor newGovernor) external;

    // Functions for claiming governance rewards by vote holders
    function claimVoteTokenRewards(uint256 epoch) external;
    function claimValueTokenRewards(uint256 epoch) external;
    function unclaimedVoteTokensForEpoch(uint256 epoch) external view returns (uint256);
}
