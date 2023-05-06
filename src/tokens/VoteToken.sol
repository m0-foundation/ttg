// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.19;

import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

import {SPOGVotes} from "./SPOGVotes.sol";
import {IVoteToken} from "../interfaces/tokens/IVoteToken.sol";

/// @title VoteToken
/// @dev Main token of vote governance.
/// @dev It relies of snapshotted balances of Value token holders at the moment of reset.
/// @dev Snapshot is taken at the moment of reset by SPOG.
/// @dev Previous value holders can mint new supply of Vote tokens to themselves.
contract VoteToken is SPOGVotes, IVoteToken {
    address public immutable valueToken;
    uint256 public resetSnapshotId;
    mapping(address => bool) public alreadyClaimed;

    constructor(string memory name, string memory symbol, address _valueToken) SPOGVotes(name, symbol) {
        valueToken = _valueToken;
    }

    /// @dev SPOG initializes reset snapshot.
    /// @param _resetSnapshotId Snapshot id of the moment of reset.
    function initReset(uint256 _resetSnapshotId) external override {
        if (resetSnapshotId != 0) revert ResetAlreadyInitialized();
        if (msg.sender != spogAddress) revert CallerIsNotSPOG();

        resetSnapshotId = _resetSnapshotId;

        emit ResetInitialized(_resetSnapshotId);
    }

    /// @dev Previous value holders can claim their share of new Vote tokens.
    function claimPreviousSupply() external override {
        if (resetSnapshotId == 0) revert ResetNotInitialized();
        if (alreadyClaimed[msg.sender]) revert ResetTokensAlreadyClaimed();

        // Make sure value holders can claim only once
        alreadyClaimed[msg.sender] = true;

        // Mint new balance of tokens to the user
        uint256 claimBalance = resetBalanceOf(msg.sender);

        // TODO: Check if we want to revert or silently fail by not minting any tokens
        if (claimBalance == 0) revert NoResetTokensToClaim();
        _mint(msg.sender, claimBalance);

        emit PreviousResetSupplyClaimed(msg.sender, claimBalance);
    }

    /// @dev Returns balance of the user at the moment of reset.
    /// @notice Fails with `ERC20Snapshot: id is 0` error if reset not initialized.
    function resetBalanceOf(address account) public view override returns (uint256) {
        return ERC20Snapshot(valueToken).balanceOfAt(account, resetSnapshotId);
    }
}
