// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

import {SPOGVotes} from "./SPOGVotes.sol";

contract VoteToken is SPOGVotes {
    address public immutable valueToken;
    uint256 public resetSnapshotId;
    bool initialized;

    // Errors
    error AlreadyClaimed();
    error AlreadyInitialized();
    error NotInitialized();

    // Events
    event PreviousSupplyClaimed(address indexed account, uint256 amount);

    mapping(address => bool) public alreadyClaimed;

    constructor(string memory name, string memory symbol, address _valueToken) SPOGVotes(name, symbol) {
        valueToken = _valueToken;
    }

    function initReset(uint256 _resetSnapshotId) external {
        if (initialized) revert AlreadyInitialized();
        require(msg.sender == spogAddress, "Only SPOG can initialize");
        initialized = true;

        resetSnapshotId = _resetSnapshotId;
    }

    function claimPreviousSupply() external {
        if (!initialized) revert NotInitialized();
        if (alreadyClaimed[msg.sender]) revert AlreadyClaimed();

        alreadyClaimed[msg.sender] = true;

        uint256 claimBalance = resetBalance();
        _mint(msg.sender, claimBalance);

        emit PreviousSupplyClaimed(msg.sender, claimBalance);
    }

    // TODO: check what happens if cnapshot taken at 0?
    function resetBalance() public view returns (uint256) {
        return ERC20Snapshot(valueToken).balanceOfAt(msg.sender, resetSnapshotId);
    }
}
