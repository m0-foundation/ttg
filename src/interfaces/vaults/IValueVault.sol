// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {IBaseVault} from "src/interfaces/vaults/IBaseVault.sol";

interface IValueVault is IBaseVault {
    // Functions for withdrawing assets by value holders
    function withdrawRewards(uint256 epoch, address token) external;
    function withdrawRewards(uint256[] memory epochs, address token) external;
}
