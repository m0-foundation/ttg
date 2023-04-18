// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {SPOGVotes} from "./SPOGVotes.sol";
import {ValueToken} from "./ValueToken.sol";

contract VoteToken is SPOGVotes {
    address public immutable valueToken;
    uint256 public immutable valueStartSnapshotId;

    uint256 private _totalSupply;

    mapping(address => int256) private _updates;

    constructor(string memory name, string memory symbol, address _valueToken) SPOGVotes(name, symbol) {
        valueToken = _valueToken;

        // TODO: make sure snapshot role is set correctly
        valueStartSnapshotId = ValueToken(valueToken).snapshot();

        _totalSupply = ERC20Snapshot(valueToken).totalSupplyAt(valueStartSnapshotId);
    }

    // ERC20 functions we need to override to make sure new balances accounting is correct
    function balanceOf(address account) public view virtual override(ERC20, IERC20) returns (uint256) {
        return _balances(account);
    }

    // Check if this function needs to be overriden at all ? or it will work with parent definition and child _totalSupply var
    function totalSupply() public view virtual override(ERC20, IERC20) returns (uint256) {
        return _totalSupply;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override(ERC20) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _updates[from] -= int256(amount);
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _updates[to] += int256(amount);
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20Votes) {
        super._mint(account, amount);

        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _updates[account] += int256(amount);
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual override(ERC20Votes) {
        super._burn(account, amount);

        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _updates[account] -= int256(amount);
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    // Balances with accounting for initial snapshot
    function _balances(address account) internal view virtual returns (uint256) {
        if (_updates[account] >= 0) {
            return ERC20Snapshot(valueToken).balanceOfAt(account, valueStartSnapshotId) + uint256(_updates[account]);
        } else {
            return ERC20Snapshot(valueToken).balanceOfAt(account, valueStartSnapshotId) - uint256(-_updates[account]);
        }
    }
}
