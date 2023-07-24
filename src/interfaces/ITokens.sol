// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IAccessControl, IERC20, IVotes } from "./ImportedInterfaces.sol";
import { ISPOGControlled } from "./ISPOGControlled.sol";

interface ISPOGToken is ISPOGControlled, IAccessControl {
    function MINTER_ROLE() external pure returns (bytes32);

    function mint(address to, uint256 amount) external;
}

interface IInflationaryVotes is IVotes, IERC20, ISPOGToken {
    // Events
    event InflationAccrued(
        address indexed account,
        address indexed delegate,
        uint256 startEpoch,
        uint256 indexed lastEpoch,
        uint256 inflation
    );

    event RewardsWithdrawn(address indexed account, address indexed delegate, uint256 amount);
    event VotingPowerAdded(address indexed account, address indexed governor, uint256 amount);

    // Errors
    error OnlyGovernor();
    error TotalVotesOverflow();
    error TotalSupplyOverflow();
    error InvalidFutureLookup();
    error VotesExpiredSignature(uint256 expiry);

    function totalVotes() external view returns (uint256);

    function getPastBalance(address account, uint256 blockNumber) external view returns (uint256);

    function getPastTotalVotes(uint256 blockNumber) external view returns (uint256);

    function addVotingPower(address account, uint256 amount) external;

    function claimInflation() external returns (uint256);
}

interface IVOTE is IInflationaryVotes {
    // Events
    event PreviousResetSupplyClaimed(address indexed account, uint256 amount);
    event ResetInitialized(uint256 indexed resetSnapshotId);

    // Errors
    error ResetTokensAlreadyClaimed();
    error ResetAlreadyInitialized();
    error ResetNotInitialized();
    error NoResetTokensToClaim();

    function value() external view returns (address);

    function resetSnapshotId() external view returns (uint256);

    function reset(uint256 resetSnapshotId) external;

    function resetBalanceOf(address account) external view returns (uint256);

    function claimPreviousSupply() external;
}

interface IVALUE is IVotes, IERC20, ISPOGToken {
    function snapshot() external returns (uint256);
}
