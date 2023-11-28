// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IThresholdGovernor } from "../abstract/interfaces/IThresholdGovernor.sol";

interface IEmergencyGovernor is IThresholdGovernor {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error InvalidRegistrarAddress();

    error InvalidStandardGovernorAddress();

    error InvalidZeroGovernorAddress();

    error NotZeroGovernor();

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function setThresholdRatio(uint16 newThresholdRatio) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function registrar() external view returns (address registrar);

    function standardGovernor() external view returns (address standardGovernor);

    function zeroGovernor() external view returns (address zeroGovernor);

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function addToList(bytes32 list, address account) external;

    function addAndRemoveFromList(bytes32 list, address accountToAdd, address accountToRemove) external;

    function removeFromList(bytes32 list, address account) external;

    function setStandardProposalFee(uint256 newProposalFee) external;

    function updateConfig(bytes32 key, bytes32 value_) external;
}
