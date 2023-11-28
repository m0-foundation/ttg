// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

interface IPowerTokenDeployer {
    error CallerIsNotRegistrar();

    error InvalidRegistrarAddress();

    error InvalidVaultAddress();

    function deploy(
        address standardGovernor,
        address cashToken,
        address bootstrapToken
    ) external returns (address deployed);

    function nextDeploy() external view returns (address nextDeploy);

    function registrar() external view returns (address registrar);

    function vault() external view returns (address vault);
}
