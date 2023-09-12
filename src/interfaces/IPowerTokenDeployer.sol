// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

interface IPowerTokenDeployer {
    error CallerIsNotRegistrar();

    function deploy(address governor, address cash) external returns (address deployed);

    function getNextDeploy() external view returns (address nextDeploy);

    function registrar() external view returns (address registrar);

    function treasury() external view returns (address treasury);

    function zeroToken() external view returns (address zeroToken);
}
