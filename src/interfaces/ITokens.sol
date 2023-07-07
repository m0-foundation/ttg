// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/interfaces/ISPOGControlled.sol";

interface ISPOGVotes is ISPOGControlled, IERC20 {
    function MINTER_ROLE() external view returns (bytes32);

    function mint(address to, uint256 amount) external;
}

interface InflationaryVotesI is IVotes {
    function getPastBalance(address account, uint256 blockNumber) external view returns (uint256);
    function getPastTotalBalanceSupply(uint256 blockNumber) external view returns (uint256);
    function addVotingPower(address account, uint256 amount) external;
    function claimVoteRewards() external returns (uint256);
    function totalVotes() external view returns (uint256);
}

interface IVote is InflationaryVotesI, ISPOGVotes {
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

interface IValue is IVotes, ISPOGVotes {
    function snapshot() external returns (uint256);
}
