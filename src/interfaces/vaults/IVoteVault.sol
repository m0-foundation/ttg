// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {SPOGGovernorBase} from "src/core/governance/SPOGGovernorBase.sol";
import {IBaseVault} from "src/interfaces/vaults/IBaseVault.sol";

interface IVoteVault is IBaseVault {
    event VoteTokenAuction(address indexed token, uint256 indexed epoch, address indexed auction, uint256 amount);
    event VoteGovernorUpdated(address indexed newVoteGovernor, address indexed newVotingToken);

    // SPOG-triggered functions
    function sellUnclaimedVoteTokens(uint256 epoch, address paymentToken, uint256 duration) external;
    function updateGovernor(SPOGGovernorBase newGovernor) external;

    // Functions for claiming governance rewards by vote holders
    function claimVoteTokenRewards(uint256 epoch) external;
    function claimValueTokenRewards(uint256 epoch) external;
    function unclaimedVoteTokensForEpoch(uint256 epoch) external view returns (uint256);
}
