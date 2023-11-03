// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

interface IDualGovernorDeployer {
    error CallerIsNotRegistrar();

    error ZeroRegistrarAddress();

    error ZeroVaultAddress();

    error ZeroZeroTokenAddress();

    function deploy(
        address cashToken,
        address powerToken,
        uint256 proposalFee,
        uint256 minProposalFee,
        uint256 maxProposalFee,
        uint256 reward,
        uint16 zeroTokenQuorumRatio,
        uint16 powerTokenQuorumRatio
    ) external returns (address deployed);

    function getNextDeploy() external view returns (address nextDeploy);

    function registrar() external view returns (address registrar);

    function vault() external view returns (address vault);

    function zeroToken() external view returns (address zeroToken);
}
