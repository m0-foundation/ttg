// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

interface IEmergencyGovernorDeployer {
    error InvalidRegistrarAddress();

    error InvalidZeroGovernorAddress();

    error NotZeroGovernor();

    function deploy(
        address powerToken,
        address standardGovernor,
        uint16 thresholdRatio
    ) external returns (address deployed);

    function lastDeploy() external view returns (address lastDeploy);

    function nextDeploy() external view returns (address nextDeploy);

    function registrar() external view returns (address registrar);

    function zeroGovernor() external view returns (address zeroGovernor);
}
