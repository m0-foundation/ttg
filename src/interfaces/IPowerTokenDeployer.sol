// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

interface IPowerTokenDeployer {
    error InvalidVaultAddress();

    error InvalidZeroGovernorAddress();

    error NotZeroGovernor();

    function deploy(
        address bootstrapToken,
        address standardGovernor,
        address cashToken
    ) external returns (address deployed);

    function lastDeploy() external view returns (address lastDeploy);

    function nextDeploy() external view returns (address nextDeploy);

    function vault() external view returns (address vault);
}
