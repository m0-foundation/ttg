// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IThresholdGovernor } from "../abstract/interfaces/IThresholdGovernor.sol";

interface IZeroGovernor is IThresholdGovernor {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error InvalidCashToken();

    error InvalidCashTokenAddress();

    error InvalidEmergencyGovernorDeployerAddress();

    error InvalidPowerTokenDeployerAddress();

    error InvalidStandardGovernorDeployerAddress();

    error NoAllowedCashTokens();

    error UnexpectedPowerTokenDeployed(address expected, address deployed);

    error UnexpectedStandardGovernorDeployed(address expected, address deployed);

    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event ResetExecuted(
        address indexed bootstrapToken,
        address standardGovernor,
        address emergencyGovernor,
        address powerToken
    );

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function emergencyGovernor() external view returns (address emergencyGovernor);

    function emergencyGovernorDeployer() external view returns (address emergencyGovernorDeployer);

    function isAllowedCashToken(address token) external view returns (bool isAllowed);

    function powerTokenDeployer() external view returns (address powerTokenDeployer);

    function standardGovernor() external view returns (address standardGovernor);

    function standardGovernorDeployer() external view returns (address standardGovernorDeployer);

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    /**
     * @notice Reset the StandardGovernor, EmergencyGovernor, and PowerToken to the PowerToken holders. This would be
     *         used by ZeroToken holders in the event that inflation is soon to result in PowerToken overflowing.
     */
    function resetToPowerHolders() external;

    /**
     * @notice Reset the StandardGovernor, EmergencyGovernor, and PowerToken to the ZeroToken holders. This would be
     *         used by ZeroToken holders if they no longer have faith in the current set of PowerToken holders and/or
     *         state of either StandardGovernor or EmergencyGovernor.
     */
    function resetToZeroHolders() external;

    function setCashToken(address newCashToken, uint256 newProposalFee) external;

    function setEmergencyProposalThresholdRatio(uint16 newThresholdRatio) external;

    function setZeroProposalThresholdRatio(uint16 newThresholdRatio) external;
}
