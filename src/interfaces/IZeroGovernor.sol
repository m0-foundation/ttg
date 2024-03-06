// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IThresholdGovernor } from "../abstract/interfaces/IThresholdGovernor.sol";

/**
 * @title  An instance of a ThresholdGovernor with a unique and limited set of possible proposals.
 * @author M^0 Labs
 */
interface IZeroGovernor is IThresholdGovernor {
    /* ============ Events ============ */

    /**
     * @notice Emitted upon contract deployment, once the set of allowed cash tokens is finalized.
     * @param  allowedCashTokens An array of addressed that are allowed as cash tokens.
     */
    event AllowedCashTokensSet(address[] allowedCashTokens);

    /**
     * @notice Emitted upon a Reset, resulting in a new Standard Governor, Emergency Governor, and Power Token.
     * @param  bootstrapToken    The address of token (Zero Token or old Power Token), that bootstraps the reset.
     * @param  standardGovernor  The address of the new Standard Governor.
     * @param  emergencyGovernor The address of the new Emergency Governor.
     * @param  powerToken        The address of the new Power Token.
     */
    event ResetExecuted(
        address indexed bootstrapToken,
        address standardGovernor,
        address emergencyGovernor,
        address powerToken
    );

    /* ============ Custom Errors ============ */

    /// @notice Revert message when the Cash Token specified is not in the allowed set.
    error InvalidCashToken();

    /// @notice Revert message when the Cash Token specified in the constructor is address(0).
    error InvalidCashTokenAddress();

    /// @notice Revert message when the Emergency Governor Deployer specified in the constructor is address(0).
    error InvalidEmergencyGovernorDeployerAddress();

    /// @notice Revert message when the Power Token Deployer specified in the constructor is address(0).
    error InvalidPowerTokenDeployerAddress();

    /// @notice Revert message when the Standard Governor Deployer specified in the constructor is address(0).
    error InvalidStandardGovernorDeployerAddress();

    /// @notice Revert message when the set of allowed cash tokens specified in the constructor is empty.
    error NoAllowedCashTokens();

    /**
     * @notice Revert message when the address of the deployed Poker Token differs fro what was expected.
     * @param  expected The expected address of the deployed Poker Token.
     * @param  deployed The actual address of the deployed Poker Token.
     */
    error UnexpectedPowerTokenDeployed(address expected, address deployed);

    /**
     * @notice Revert message when the address of the deployed Standard Governor differs fro what was expected.
     * @param  expected The expected address of the deployed Standard Governor.
     * @param  deployed The actual address of the deployed Standard Governor.
     */
    error UnexpectedStandardGovernorDeployed(address expected, address deployed);

    /* ============ Proposal Functions ============ */

    /**
     * @notice One of the valid proposals. Reset the Standard Governor, Emergency Governor, and Power Token to the
     *         Power Token holders. This would be used by Zero Token holders in the event that inflation is soon to
     *         result in Power Token overflowing, and/or there is a loss of faith in the state of either the Standard
     *         Governor or Emergency Governor.
     */
    function resetToPowerHolders() external;

    /**
     * @notice One of the valid proposals. Reset the Standard Governor, Emergency Governor, and Power Token to the
     *         ZeroToken holders. This would be used by Zero Token holders if they no longer have faith in the current
     *         set of PowerToken holders and/or the state of either the Standard Governor or Emergency Governor.
     */
    function resetToZeroHolders() external;

    /**
     * @notice One of the valid proposals. Sets the Cash Token of the system.
     * @param  newCashToken   The address of the new cash token.
     * @param  newProposalFee The amount of cash token required onwards to create Standard Governor proposals.
     */
    function setCashToken(address newCashToken, uint256 newProposalFee) external;

    /**
     * @notice One of the valid proposals. Sets the threshold ratio for Emergency Governor proposals.
     * @param  newThresholdRatio The new threshold ratio.
     */
    function setEmergencyProposalThresholdRatio(uint16 newThresholdRatio) external;

    /**
     * @notice One of the valid proposals. Sets the threshold ratio for this governor's proposals.
     * @param  newThresholdRatio The new threshold ratio.
     */
    function setZeroProposalThresholdRatio(uint16 newThresholdRatio) external;

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns whether `token` is an allowed Cash Token of the system, as a parameter in setCashToken proposal.
     * @param  token The address of some token.
     * @return Whether `token` is an allowed Cash Token.
     */
    function isAllowedCashToken(address token) external view returns (bool);

    /// @notice Returns the address of the Emergency Governor.
    function emergencyGovernor() external view returns (address);

    /// @notice Returns the address of the Emergency Governor Deployer.
    function emergencyGovernorDeployer() external view returns (address);

    /// @notice Returns the address of the Power Token Deployer.
    function powerTokenDeployer() external view returns (address);

    /// @notice Returns the address of the Standard Governor.
    function standardGovernor() external view returns (address);

    /// @notice Returns the address of the Standard Governor Deployer.
    function standardGovernorDeployer() external view returns (address);
}
