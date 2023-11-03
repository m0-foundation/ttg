// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { ERC20Permit } from "../../src/ERC20Permit.sol";
import { ERC712 } from "../../src/ERC712.sol";

contract ERC20PermitHarness is ERC20Permit {
    uint256 public totalSupply;

    mapping(address account => uint256 balance) public balanceOf;

    constructor(
        string memory symbol_,
        string memory name_,
        uint8 decimals_
    ) ERC20Permit(symbol_, decimals_) ERC712(name_) {}

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
