// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { ERC20Extended } from "../../lib/common/src/ERC20Extended.sol";

contract ERC20ExtendedHarness is ERC20Extended {
    uint256 internal _totalSupply;

    mapping(address account => uint256 balance) public _balances;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 decimals_
    ) ERC20Extended(name_, symbol_, uint8(decimals_)) {}

    function mint(address recipient_, uint256 amount_) external {
        _balances[recipient_] += amount_;
        _totalSupply += amount_;

        emit Transfer(address(0), recipient_, amount_);
    }

    function balanceOf(address account_) external view override returns (uint256 balance_) {
        return _balances[account_];
    }

    function totalSupply() external view override returns (uint256 totalSupply_) {
        return _totalSupply;
    }

    function _transfer(address sender_, address recipient_, uint256 amount_) internal override {
        _balances[sender_] -= amount_;
        _balances[recipient_] += amount_;

        emit Transfer(sender_, recipient_, amount_);
    }
}
