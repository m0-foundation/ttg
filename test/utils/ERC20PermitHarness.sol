// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { ERC20Permit } from "../../src/abstract/ERC20Permit.sol";
import { ERC712 } from "../../src/abstract/ERC712.sol";

contract ERC20PermitHarness is ERC20Permit {
    uint256 public totalSupply;

    mapping(address account => uint256 balance) public balanceOf;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 decimals_
    ) ERC20Permit(name_, symbol_, uint8(decimals_)) {}

    function mint(address recipient_, uint256 amount_) external {
        balanceOf[recipient_] += amount_;
        totalSupply += amount_;

        emit Transfer(address(0), recipient_, amount_);
    }

    function _transfer(address sender_, address recipient_, uint256 amount_) internal override {
        balanceOf[sender_] -= amount_;
        balanceOf[recipient_] += amount_;

        emit Transfer(sender_, recipient_, amount_);
    }
}
