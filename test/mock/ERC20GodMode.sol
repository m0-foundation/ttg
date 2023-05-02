// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract ERC20GodMode is ERC20Mock {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20Mock(name, symbol, msg.sender, 0) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
