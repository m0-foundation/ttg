// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IThresholdGovernor } from "./IThresholdGovernor.sol";

interface IZeroGovernor is IThresholdGovernor {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error InvalidCashToken();

    error InvalidCashTokenAddress();

    error NoAllowedCashTokens();

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function emergencyGovernor() external view returns (address emergencyGovernor);

    function isAllowedCashToken(address token) external view returns (bool isAllowed);

    function standardGovernor() external view returns (address standardGovernor);

    function startingCashToken() external view returns (address startingCashToken);

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function resetToPowerHolders() external;

    function resetToZeroHolders() external;

    function setCashToken(address newCashToken, uint256 newProposalFee) external;

    function setEmergencyProposalThresholdRatio(uint16 newThresholdRatio) external;

    function setZeroProposalThresholdRatio(uint16 newThresholdRatio) external;
}
