// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {IBaseVault} from "src/interfaces/vaults/IBaseVault.sol";

interface IValueVault is IBaseVault {
    // Function for withdrawing assets by value holders
    function withdrawRewards(uint256[] calldata epochs, address token) external;
}
