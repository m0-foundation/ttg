// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IEpochBasedMintableVoteToken } from "./interfaces/IEpochBasedMintableVoteToken.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";

import { EpochBasedVoteToken } from "./EpochBasedVoteToken.sol";

contract EpochBasedMintableVoteToken is IEpochBasedMintableVoteToken, EpochBasedVoteToken {
    address internal immutable _registrar;

    modifier onlGovernor() {
        if (msg.sender != IRegistrar(_registrar).governor()) revert NotGovernor();

        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address registrar_
    ) EpochBasedVoteToken(name_, symbol_, decimals_) {
        _registrar = registrar_;
    }

    function mint(address recipient, uint256 amount) external onlGovernor {
        _mint(recipient, amount);
    }

    function registrar() external view returns (address registrar_) {
        registrar_ = _registrar;
    }
}
