// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

interface IStandardGovernorDeployer {
    error CallerIsNotRegistrar();

    error InvalidRegistrarAddress();

    error InvalidVaultAddress();

    error InvalidZeroGovernorAddress();

    error InvalidZeroTokenAddress();

    function deploy(
        address powerToken,
        address emergencyGovernor,
        address cashToken,
        uint256 proposalFee,
        uint256 maxTotalZeroRewardPerActiveEpoch
    ) external returns (address deployed);

    function nextDeploy() external view returns (address nextDeploy);

    function registrar() external view returns (address registrar);

    function vault() external view returns (address vault);

    function zeroGovernor() external view returns (address zeroGovernor);

    function zeroToken() external view returns (address zeroToken);
}
