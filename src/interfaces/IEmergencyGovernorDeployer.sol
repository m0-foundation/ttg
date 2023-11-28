// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

interface IEmergencyGovernorDeployer {
    error CallerIsNotRegistrar();

    error InvalidRegistrarAddress();

    error InvalidZeroGovernorAddress();

    function deploy(
        address powerToken,
        address standardGovernor,
        uint16 thresholdRatio
    ) external returns (address deployed);

    function nextDeploy() external view returns (address nextDeploy);

    function registrar() external view returns (address registrar);

    function zeroGovernor() external view returns (address zeroGovernor);
}
