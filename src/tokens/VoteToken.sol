// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

import {SPOGVotes} from "./SPOGVotes.sol";

/// @title VoteToken
/// @dev Main token of vote governance.
/// @dev It relies of snapshotted balances of Value token holders at the moment of reset.
/// @dev Snapshot is taken at the moment of reset by SPOG.
/// @dev Previous value holders can mint new supply of Vote tokens to themselves.
contract VoteToken is SPOGVotes {
    address public immutable valueToken;
    uint256 public resetSnapshotId;
    mapping(address => bool) public alreadyClaimed;

    // Errors
    error ResetTokensAlreadyClaimed();
    error ResetAlreadyInitialized();
    error ResetNotInitialized();

    // Events
    event PreviousResetSupplyClaimed(address indexed account, uint256 amount);
    event ResetInitialized(uint256 indexed resetSnapshotId);

    constructor(string memory name, string memory symbol, address _valueToken) SPOGVotes(name, symbol) {
        valueToken = _valueToken;
    }

    /// @dev SPOG initializes reset snapshot.
    /// @param _resetSnapshotId Snapshot id of the moment of reset.
    function initReset(uint256 _resetSnapshotId) external {
        if (resetSnapshotId != 0) revert ResetAlreadyInitialized();
        if (msg.sender != spogAddress) revert CallerIsNotSPOG();

        resetSnapshotId = _resetSnapshotId;

        emit ResetInitialized(_resetSnapshotId);
    }

    /// @dev Previous value holders can claim their share of new Vote tokens.
    function claimPreviousSupply() external {
        if (resetSnapshotId == 0) revert ResetNotInitialized();
        if (alreadyClaimed[msg.sender]) revert ResetTokensAlreadyClaimed();

        // Make sure value holders can claim only once
        alreadyClaimed[msg.sender] = true;

        // Mint new balance of tokens to the user
        uint256 claimBalance = resetBalance();
        _mint(msg.sender, claimBalance);

        emit PreviousResetSupplyClaimed(msg.sender, claimBalance);
    }

    // TODO: check what happens if snapshot taken at 0?
    /// @dev Returns balance of the user at the moment of reset.
    function resetBalance() public view returns (uint256) {
        return ERC20Snapshot(valueToken).balanceOfAt(msg.sender, resetSnapshotId);
    }
}
