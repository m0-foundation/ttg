// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.19;

import "src/interfaces/tokens/ISPOGVotes.sol";

interface IVoteToken is ISPOGVotes {
    // Errors
    error ResetTokensAlreadyClaimed();
    error ResetAlreadyInitialized();
    error ResetNotInitialized();
    error NoResetTokensToClaim();

    // Events
    event PreviousResetSupplyClaimed(address indexed account, uint256 amount);
    event ResetInitialized(uint256 indexed resetSnapshotId);

    function valueToken() external view returns (address);

    function reset(uint256 _resetSnapshotId) external;
    function resetBalanceOf(address account) external view returns (uint256);
    function claimPreviousSupply() external;
}
