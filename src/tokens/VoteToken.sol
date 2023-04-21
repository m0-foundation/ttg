// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

import {SPOGVotes} from "./SPOGVotes.sol";

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

    function initReset(uint256 _resetSnapshotId) external {
        if (resetSnapshotId != 0) revert ResetAlreadyInitialized();
        if (msg.sender != spogAddress) revert CallerIsNotSPOG();

        resetSnapshotId = _resetSnapshotId;

        emit ResetInitialized(_resetSnapshotId);
    }

    function claimPreviousSupply() external {
        if (resetSnapshotId == 0) revert ResetNotInitialized();
        if (alreadyClaimed[msg.sender]) revert ResetTokensAlreadyClaimed();

        alreadyClaimed[msg.sender] = true;

        uint256 claimBalance = resetBalance();
        _mint(msg.sender, claimBalance);

        emit PreviousResetSupplyClaimed(msg.sender, claimBalance);
    }

    // TODO: check what happens if cnapshot taken at 0?
    function resetBalance() public view returns (uint256) {
        return ERC20Snapshot(valueToken).balanceOfAt(msg.sender, resetSnapshotId);
    }
}
