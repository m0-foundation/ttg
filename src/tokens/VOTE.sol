// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.19;

import { IVOTE } from "./ITokens.sol";

import { ERC20, ERC20Permit, ERC20Snapshot } from "../ImportedContracts.sol";
import { InflationaryVotes } from "./InflationaryVotes.sol";

/// @title VOTE token with built-in inflation
/// @dev It relies of snapshotted balances of VALUE token holders at the moment of reset
/// @dev Snapshot is taken at the moment of reset by Comptroller
/// @dev Previous value holders can mint new supply of Vote tokens to themselves
contract VOTE is IVOTE, InflationaryVotes {
    /// @notice value token to take snapshot from
    address public immutable value;

    /// @notice snapshot id at the moment of reset
    uint256 public resetSnapshotId;

    /// @dev check that balances are claimed only once
    mapping(address account => bool hasAlreadyClaimed) private _alreadyClaimed;

    /// @notice Constructs the VOTE token
    /// @param name Name of the token
    /// @param symbol Symbol of the token
    /// @param comptroller Address of the Comptroller contract
    /// @param value_ Address of the VALUE token for reset
    constructor(
        string memory name,
        string memory symbol,
        address comptroller,
        address value_
    ) InflationaryVotes(comptroller) ERC20(name, symbol) ERC20Permit(name) {
        value = value_;
    }

    /// @notice Comptroller initializes reset snapshot
    /// @param resetSnapshotId_ Snapshot id of the moment of reset
    function reset(uint256 resetSnapshotId_) external {
        if (resetSnapshotId != 0) revert ResetAlreadyInitialized();
        if (msg.sender != comptroller) revert CallerIsNotComptroller();

        resetSnapshotId = resetSnapshotId_;

        emit ResetInitialized(resetSnapshotId_);
    }

    /// @notice Claim share of new vote tokens by previous value holders
    function claimPreviousSupply() external {
        if (resetSnapshotId == 0) revert ResetNotInitialized();
        if (_alreadyClaimed[msg.sender]) revert ResetTokensAlreadyClaimed();

        // Make sure value holders can claim only once
        _alreadyClaimed[msg.sender] = true;

        // Mint new balance of tokens to the user
        uint256 claimBalance = resetBalanceOf(msg.sender);

        // TODO: Check if we want to revert or silently fail by not minting any tokens
        if (claimBalance == 0) revert NoResetTokensToClaim();

        _mint(msg.sender, claimBalance);

        emit PreviousResetSupplyClaimed(msg.sender, claimBalance);
    }

    /// @notice Returns balance of the user at the moment of reset.
    /// @dev Fails with `ERC20Snapshot: id is 0` error if reset not initialized.
    function resetBalanceOf(address account) public view returns (uint256) {
        return ERC20Snapshot(value).balanceOfAt(account, resetSnapshotId);
    }

    /// @notice Restricts minting to the governor.
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyGovernor {
        _mint(to, amount);
    }
}
