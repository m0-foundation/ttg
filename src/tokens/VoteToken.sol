// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

import {SPOGVotes} from "./SPOGVotes.sol";

contract VoteToken is SPOGVotes {
    address public immutable valueToken;
    uint256 public immutable resetSnapshotId;

    // Errors
    error AlreadyClaimed();

    // Events
    event PreviousSupplyClaimed(address indexed account, uint256 amount);

    mapping(address => bool) public alreadyClaimed;

    constructor(string memory name, string memory symbol, address _valueToken, uint256 _resetSnapshotId)
        SPOGVotes(name, symbol)
    {
        valueToken = _valueToken;
        resetSnapshotId = _resetSnapshotId;
    }

    function claimPreviousSupply() external {
        if (alreadyClaimed[msg.sender]) {
            revert AlreadyClaimed();
        }
        alreadyClaimed[msg.sender] = true;

        uint256 claimBalance = resetBalance();
        _mint(msg.sender, claimBalance);

        emit PreviousSupplyClaimed(msg.sender, claimBalance);
    }

    function resetBalance() public view returns (uint256) {
        return ERC20Snapshot(valueToken).balanceOfAt(msg.sender, resetSnapshotId);
    }
}
