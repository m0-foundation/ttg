// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.19;

import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";

interface IVoteToken is ISPOGVotes {
    // Errors
    error ResetTokensAlreadyClaimed();
    error ResetAlreadyInitialized();
    error ResetNotInitialized();
    error NoResetTokensToClaim();

    // Events
    event PreviousResetSupplyClaimed(address indexed account, uint256 amount);
    event ResetInitialized(uint256 indexed resetSnapshotId);

    function initReset(uint256 _resetSnapshotId) external;

    function claimPreviousSupply() external;

    function resetBalanceOf(address account) external view returns (uint256);

    function valueToken() external view returns (address);
}
